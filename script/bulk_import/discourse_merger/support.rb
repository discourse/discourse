# frozen_string_literal: true

require_relative "configuration"
require_relative "group_mapping"
require_relative "media"
require_relative "matched_avatars"
require_relative "reviewed_post_uploads"
require_relative "reviewed_revision_uploads"
require "json"
require "digest"
require "uri"

module BulkImport::DiscourseMerge
  # Apply and verify both hold a read-only source transaction for the duration of a scan.
  module SourceRows
    def self.each(connection, sql, &block)
      each_batch(connection, sql) { |rows| rows.each(&block) }
    end

    def self.each_batch(connection, sql)
      connection.exec("DECLARE merge_source_rows NO SCROLL CURSOR FOR #{sql}")
      begin
        loop do
          rows = connection.exec("FETCH FORWARD 1000 FROM merge_source_rows").to_a
          break if rows.empty?
          yield rows
          break if rows.size < 1000
        end
      ensure
        unless connection.transaction_status == PG::PQTRANS_INERROR
          connection.exec("CLOSE merge_source_rows")
        end
      end
    end
  end

  class Plan
    attr_reader :data, :topics, :categories, :excluded_ids, :retained_category_ids

    def initialize(data)
      @data = data
      raise Error, "Unsupported manifest" if [1, 2, 3, 4].exclude?(data.fetch("format_version"))
      @topics = data.fetch("topics").index_by { |r| Integer(r.fetch("source_topic_id")) }
      raise Error, "Duplicate topic IDs" unless @topics.size == data.fetch("topics").size
      @categories = data.fetch("categories").index_by { |r| r.fetch("key") }
      @excluded_ids =
        @topics
          .select { |_, r| %w[exclude exclude_obsolete_description].include?(r.fetch("action")) }
          .keys
          .to_set
      @retained_category_ids = @categories.values.filter_map { |r| r["source_category_id"] }.to_set
    end

    def included_ids
      topics.keys.to_set - excluded_ids
    end

    def preserve_staff_roles?
      data.dig("policy", "source_staff_roles") != "regular_users"
    end

    def topic(id)
      topics.fetch(Integer(id))
    end

    def sql_ids(ids)
      values = ids.map { |id| Integer(id) }.sort
      values.empty? ? "NULL" : values.join(",")
    end
  end

  # Select only source records whose references can be mapped. This wraps
  # core's existing SELECT, including its name-collision projections.
  class Selection
    def initialize(plan)
      @plan = plan
      @excluded_groups = GroupMapping.excluded(plan.data.fetch("groups", []))
    end

    def included_topics
      @included_topics ||= @plan.sql_ids(@plan.included_ids)
    end

    def topic_test(expression)
      "#{expression} IN (#{included_topics})"
    end

    def post_test(expression)
      "#{expression} IN (SELECT id FROM posts WHERE topic_id IN (#{included_topics}))"
    end

    def sql(table, columns, original, auto_groups: [])
      raise Error, "Unsafe table name" unless table.match?(/\A[a-z][a-z0-9_]*\z/)
      conditions = []
      if columns.include?("group_id") && @excluded_groups.any?
        conditions << "(r.group_id IS NULL OR r.group_id NOT IN (#{@plan.sql_ids(@excluded_groups)}))"
      end
      %w[topic_id target_topic_id link_topic_id].each do |column|
        next if columns.exclude?(column)
        conditions << "(r.#{column} IS NULL OR #{topic_test("r.#{column}")})"
      end
      %w[
        post_id
        target_post_id
        related_post_id
        reply_post_id
        quoted_post_id
        link_post_id
      ].each do |column|
        next if columns.exclude?(column)
        conditions << "(r.#{column} IS NULL OR #{post_test("r.#{column}")})"
      end
      if columns.include?("bookmarkable_id")
        conditions << "((r.bookmarkable_type = 'Topic' AND #{topic_test("r.bookmarkable_id")}) OR (r.bookmarkable_type = 'Post' AND #{post_test("r.bookmarkable_id")}))"
      end
      if columns.include?("timerable_id")
        raise Error, "Unsupported timer schema" if columns.exclude?("type")
        conditions << "r.type = 'TopicTimer' AND #{topic_test("r.timerable_id")}"
      end
      if columns.include?("category_id") && table.start_with?("category_")
        conditions << "r.category_id IN (#{@plan.sql_ids(@plan.retained_category_ids)})"
      end
      if table == "group_users" && auto_groups.any?
        conditions << "r.group_id NOT IN (#{@plan.sql_ids(auto_groups)})"
      end
      if table == "topic_allowed_users"
        conditions << "EXISTS (SELECT 1 FROM users u WHERE u.id = r.user_id)"
      elsif table == "topic_allowed_groups"
        conditions << "EXISTS (SELECT 1 FROM groups g WHERE g.id = r.group_id)"
      end
      if conditions.empty?
        original
      else
        "SELECT r.* FROM (#{original}) r WHERE #{conditions.join(" AND ")}"
      end
    end
  end

  class References
    def self.from_plan(plan, maps, usernames:, group_names:, media_urls:, source_connection: nil)
      policy = plan.data.fetch("policy")
      new(
        source_connection: source_connection,
        rewrite_letter_avatars: plan.data.fetch("rewrite_letter_avatars", false),
        source_host: policy.fetch("source_host"),
        destination_host: policy.fetch("destination_host"),
        topics: maps.fetch(:topics),
        categories: maps.fetch(:categories),
        usernames: usernames,
        group_names: group_names,
        destination_base_url: policy.fetch("destination_url"),
        source_base_url: policy.fetch("source_url").delete_suffix("/"),
        upload_mode: plan.data.dig("upload_policy", "mode"),
        media_urls: media_urls,
        uploads: maps[:uploads] || {},
        users: maps[:users] || {},
        matched_avatars: plan.data.fetch("matched_avatars", []),
        preserved_broken_post_uploads: plan.data.fetch("preserved_broken_post_uploads", []),
        preserved_broken_revision_uploads: plan.data.fetch("preserved_broken_revision_uploads", []),
        media_origins: plan.data.dig("upload_policy", "media_origins", "source") || {},
        verify_media: plan.data.dig("upload_policy", "mode") == "preuploaded",
        emoji_urls:
          plan
            .data
            .fetch("content", {})
            .fetch("custom_emojis", [])
            .filter_map { |r| r["render"] }
            .to_h,
      )
    end

    def self.post_locker(source_id, users)
      users.fetch(source_id.to_i, -1) if source_id
    end

    def initialize(
      rewrite_letter_avatars: true,
      source_connection: nil,
      source_host:,
      destination_host:,
      topics:,
      categories:,
      usernames: {},
      group_names: {},
      destination_base_url: nil,
      source_base_url: nil,
      upload_mode: "copy",
      media_urls: {},
      uploads: {},
      users: {},
      matched_avatars: [],
      preserved_broken_post_uploads: [],
      preserved_broken_revision_uploads: [],
      media_origins: {},
      verify_media: false,
      emoji_urls: {}
    )
      @rewrite_letter_avatars = rewrite_letter_avatars
      @source_connection = source_connection
      @source_host, @destination_host = source_host, destination_host
      @destination_url = (destination_base_url || "https://#{destination_host}").delete_suffix("/")
      @topics, @categories = topics, categories
      @usernames = usernames.transform_keys(&:downcase)
      @groups = group_names.transform_keys(&:downcase)
      @upload_mode = upload_mode
      @source_url = source_base_url || "https://#{source_host}"
      @emoji_urls = emoji_urls
      @media_urls = media_urls
      @uploads = uploads
      @users = users
      @avatar_by_username, @avatar_by_user_id = {}, {}
      matched_avatars.each do |decision|
        decision
          .fetch("sources")
          .each do |source_id, name|
            @avatar_by_username[name.downcase] = decision
            @avatar_by_user_id[Integer(source_id)] = decision
          end
      end
      @remap_upload_avatars = %w[preuploaded prepared_destination].include?(upload_mode)
      if @remap_upload_avatars || matched_avatars.any?
        @avatar_hosts = [source_host, URI.parse(@source_url).host]
        if media_origins["base_url"].present?
          @avatar_hosts << URI.parse(Media.remote_url(media_origins["base_url"], @source_url)).host
        end
        bases =
          [@source_url, *media_origins.values.compact_blank].map do |url|
            Media.remote_url(url, @source_url).delete_suffix("/").sub(/\Ahttps?:/, "")
          end
        origins = Regexp.union(bases.uniq.sort_by { |base| -base.length })
        @avatar_urls =
          %r{(?<![\w/.:])(?:(?:https?:)?(?:#{origins}))?/user_avatar/([^/\s]+)/([\w.%~-]+)/(\d+)/(\d+)(?:_\d+)?\.png}i
        @external_avatars =
          %r{(?<![\w/.:])(?:https?:)?(?:#{origins})/avatars/(\d+)/(\d+)/(\d+)(?:_\d+)?\.png}i
      end
      @preserved_post_urls =
        preserved_broken_post_uploads
          .group_by { |entry| entry.fetch("source_post_id") }
          .transform_values { |entries| ReviewedPostUploads.pattern(entries.pluck("url")) }
      @preserved_revision_urls =
        preserved_broken_revision_uploads.to_h do |entry|
          [entry.fetch("source_revision_id"), ReviewedRevisionUploads.pattern(entry.fetch("urls"))]
        end
      @verify_media = verify_media
      if verify_media
        hosts = Regexp.union([@source_host, @destination_host].uniq)
        @native_short_urls =
          %r{(?<![\w/.:])(?:upload://|(?:(?:https?:)?//(?:#{hosts}))?/uploads/short-url/)([a-zA-Z0-9]+)}
      end
    end

    def rewrite(text, cooked: false, source_post_id: nil, source_revision_id: nil)
      return text unless text.is_a?(String)
      preserved = @preserved_post_urls[source_post_id]
      revision_urls = @preserved_revision_urls[source_revision_id]
      # Do not turn examples inside Markdown code spans/fences into links or mentions.
      if cooked
        return(
          text
            .split(%r{(<pre\b[^>]*>.*?</pre>|<code\b[^>]*>.*?</code>)}im)
            .map
            .with_index do |part, i|
              if i.odd?
                part
              else
                rewrite_emoji(rewrite_content(part, true, preserved, revision_urls))
              end
            end
            .join
        )
      end
      text
        .split(/(```[^\n]*\n.*?```|~~~[^\n]*\n.*?~~~|`+[^`\n]*`+)/m)
        .map
        .with_index do |part, index|
          if index.odd?
            part
          else
            rewrite_content(part, false, preserved, revision_urls)
          end
        end
        .join
    end

    def rewrite_content(text, cooked, preserved, revision_urls)
      unless @rewrite_letter_avatars && @upload_mode != "prepared_destination" &&
               text.include?("/letter_avatar_proxy/")
        return rewrite_segment(text, preserved, revision_urls)
      end

      origin = Regexp.escape(@source_url.delete_suffix("/").sub(/\Ahttps?:/, ""))
      image =
        %r{(?<url>(?:(?:https?:)?#{origin})?/letter_avatar_proxy/(?<asset>v\d+/letter/(?:[[:alnum:]]|%[0-9a-f]{2})+/[0-9a-f]{6}/(?<size>\d+)\.png))}i
      profile = %r{(?:(?:https?:)?#{origin})?/u/(?<member>[\w.%-]+)}i
      pattern =
        if cooked
          tag = /<img\b[^<>]*?\ssrc="#{image}"[^<>]*>/i
          link = /<a\b[^<>]*?\shref="#{profile}"[^<>]*>/i
          %r{(?:#{link}\s*#{tag}\s*</a>|#{tag}(?:[ \t]*#{link}@[^<>]+</a>)?)}i
        else
          tag = /!\[avatar(?:\\?\|[^\]\n]*)?\]\(#{image}\)/i
          /(?:\[#{tag}\]\(#{profile}\)|#{tag}(?:[ \t]+(?:@(?<mention>[\w.-]+)|\[@[^\]\n]+\]\(#{profile}\)))?)/i
        end

      # Rewrite the surrounding source text, keeping emitted destination URLs out of the source maps.
      output = +""
      offset = 0
      text.scan(pattern) do
        match = Regexp.last_match
        member = match.named_captures["mention"] || match[:member]
        url = embedded_avatar_for(member, match[:size]) if member
        url ||= "https://avatars.discourse-cdn.com/#{match[:asset]}"
        prefix = text[offset...match.begin(0)]
        before = text[match.begin(0)...match.begin(:url)]
        after = text[match.end(:url)...match.end(0)]
        if cooked
          before = before.sub(/(<img\b[^<>]*?)\ssrcset="[^"]*"/i, '\1')
          after = after.sub(/\A([^<>]*?)\ssrcset="[^"]*"/i, '\1')
        end
        output << rewrite_segment(prefix + before, preserved, revision_urls) << url
        output << rewrite_segment(after, preserved, revision_urls)
        offset = match.end(0)
      end
      output << rewrite_segment(text[offset..], preserved, revision_urls)
    end

    def embedded_avatar_for(member, size)
      name = URI::DEFAULT_PARSER.unescape(member).downcase
      decision = @avatar_by_username[name]
      return matched_avatar_url(decision, size) if decision

      return unless @source_connection
      @source_avatar_members ||=
        @source_connection
          .exec("SELECT id, username, username_lower, uploaded_avatar_id FROM users WHERE id > 0")
          .index_by { |row| row.fetch("username_lower") }
      account = @source_avatar_members[name]
      return unless account && @users.key?(Integer(account.fetch("id")))
      final = @usernames.fetch(name, account.fetch("username"))
      upload = @uploads[account["uploaded_avatar_id"].to_i]
      member_avatar_url(final, size, upload)
    end

    def rewrite_emoji(html)
      return html if @emoji_urls.empty?
      html.gsub(/<img\b[^>]*>/i) do |tag|
        next tag if tag.exclude?("emoji")
        image = Nokogiri::HTML5.fragment(tag).at_css("img.emoji")
        name = image && (image["alt"] || image["title"]).to_s.delete_prefix(":").delete_suffix(":")
        next tag unless (url = @emoji_urls[name])
        image["src"] = url
        image.remove_attribute("srcset")
        image.to_html
      end
    end

    def rewrite_segment(text, preserved = nil, revision_urls = nil)
      if revision_urls
        return(
          text
            .split(revision_urls)
            .map
            .with_index { |part, i| i.odd? ? part : rewrite_segment(part, preserved) }
            .join
        )
      end
      text = rewrite_known_media(text) unless @media_urls.empty?
      if @verify_media
        text.scan(@native_short_urls) do |(encoded)|
          next if preserved && text.match?(preserved, Regexp.last_match.begin(0))
          @upload_hashes ||= Upload.unscoped.where.not(sha1: nil).pluck(:sha1).to_set
          if @upload_hashes.exclude?(Upload.sha1_from_base62_encoded(encoded))
            raise Error, "Unresolved native upload short URL: #{encoded}"
          end
        end
        if text.match?(%r{(?<![\w/.:])/(?:uploads/[^/\s<>"']+/(?:original|optimized)/\d+X/)})
          raise Error, "Unresolved local upload path in merged content"
        end
      end
      if @avatar_urls
        text =
          text.gsub(@avatar_urls) do |original|
            host, username, size, upload = Regexp.last_match.captures
            next original unless @avatar_hosts.any? { |known| host.casecmp?(known) }
            decision = @avatar_by_username[URI::DEFAULT_PARSER.unescape(username).downcase]
            next matched_avatar_url(decision, size) if decision
            next original unless @remap_upload_avatars
            avatar_url(@usernames.fetch(username.downcase, username), size, upload)
          end
        text =
          text.gsub(@external_avatars) do |url|
            original, size, upload = Regexp.last_match.captures
            decision = @avatar_by_user_id[original.to_i]
            next matched_avatar_url(decision, size) if decision
            next url unless @remap_upload_avatars
            user_id =
              @upload_mode == "prepared_destination" ? original.to_i : @users.fetch(original.to_i)
            @avatar_usernames ||= {}
            username =
              @avatar_usernames[user_id] ||= User
                .unscoped
                .find(user_id)
                .encoded_username(lower: true)
            avatar_url(username, size, upload)
          end
      end
      return text if @upload_mode == "prepared_destination"
      if @upload_mode == "preuploaded"
        origin = Regexp.escape(@source_host)
        text =
          text.gsub(
            %r{(?<![\w/.:])(?:(?:https?:)?//#{origin})?(/uploads/short-url/[a-zA-Z0-9]+)}i,
          ) { "#{@destination_url}#{Regexp.last_match(1)}" }
      end
      if @upload_mode == "preserve_remote"
        text =
          text.gsub(%r{(?<![\w/.:])/(?:uploads|user_avatar)/[^\s<>"'\]\)]+}) do |url|
            Media.remote_url(url, @source_url)
          end
      end
      result =
        text.gsub(/\[quote="([^"\n]*)"\]/i) do |header|
          attributes = Regexp.last_match(1)
          original = attributes[/\btopic:(\d+)/, 1]
          next header if original && !@topics[original.to_i]
          attributes =
            attributes.sub(/\btopic:(\d+)/) do
              "topic:#{@topics.fetch(Regexp.last_match(1).to_i)}"
            end if original
          attributes = attributes.sub(/\A([^,]+)/) { |name| @usernames[name.downcase] || name }
          "[quote=\"#{attributes}\"]"
        end
      host = Regexp.escape(@source_host)
      # Boundaries exclude other domains and paths embedded in another URL.
      result =
        result.gsub(
          %r{(?<![\w/.:])(?:(?:https?:)?//#{host})?/t/(?:(?!\d+(?:/|$))[^/\s<>"\]\)]+/)?(\d+)(/\d+)?(?=[/\s<>"\]\)?#.,!;:]|$)}i,
        ) do |url|
          id, number = Regexp.last_match(1).to_i, Regexp.last_match(2)
          mapped = @topics[id]
          mapped ? "#{@destination_url}/t/#{mapped}#{number}" : url
        end
      result =
        result.gsub(
          %r{(?<![\w/.:])(?:(?:https?:)?//#{host})?/c/(?:[^\s<>"\]\)]+/)?(\d+)(?=[/\s<>"\]\)?#.,!;:]|$)}i,
        ) do |url|
          mapped = @categories[Regexp.last_match(1).to_i]
          mapped ? "#{@destination_url}/c/#{mapped}" : url
        end
      result =
        result.gsub(%r{(?<![\w/.:])(?:(?:https?:)?//#{host})?/(u|g)/([A-Za-z0-9_.-]+)}i) do
          type, name = Regexp.last_match(1), Regexp.last_match(2)
          mapped = (type == "u" ? @usernames : @groups)[name.downcase] || name
          "#{@destination_url}/#{type}/#{mapped}"
        end
      paths = @upload_mode == "copy" ? "uploads/|tag/|tags/" : "tag/|tags/"
      result = result.gsub(%r{https?://#{host}(?=/(?:#{paths}))}i, "#{@destination_url}")
      result.gsub(/(?<![\w@.])@([A-Za-z0-9_][A-Za-z0-9_.-]*[A-Za-z0-9_]|[A-Za-z0-9_])/) do |mention|
        name = Regexp.last_match(1)
        replacement = @usernames[name.downcase] || @groups[name.downcase]
        replacement ? "@#{replacement}" : mention
      end
    end

    def matched_avatar_url(decision, size)
      name = decision.fetch("username")
      id = MatchedAvatars.destination_upload(decision, @uploads)
      member_avatar_url(name, size, id)
    end

    def member_avatar_url(name, size, id)
      return destination_avatar_url(URI.encode_uri_component(name.downcase), size, id) if id
      url = default_avatar_url(name, size)
      return url unless @rewrite_letter_avatars
      url.sub(
        %r{\A#{Regexp.escape(@destination_url)}/letter_avatar_proxy/},
        "https://avatars.discourse-cdn.com/",
      )
    end

    def default_avatar_url(name, size)
      url = User.default_template(name).gsub("{size}", size)
      if url.start_with?("/") && !url.start_with?("//")
        url = url.delete_prefix(Discourse.base_path + "/")
        return "#{@destination_url}/#{url.delete_prefix("/")}"
      end
      Media.remote_url(url, @destination_url)
    end

    def avatar_url(username, size, upload)
      id = @upload_mode == "prepared_destination" ? upload.to_i : @uploads.fetch(upload.to_i)
      destination_avatar_url(username, size, id)
    end

    def destination_avatar_url(username, size, id)
      "#{@destination_url}/user_avatar/#{URI.parse(@destination_url).host}/#{username}/#{size}/#{id}_#{OptimizedImage::VERSION}.png"
    end

    def rewrite_known_media(text)
      unless defined?(@media_candidates)
        prefixes, literals = Set.new, []
        @media_urls.each_key do |url|
          prefix = url[%r{\A(?:https?://|//|/|[^/\s]+/)}]
          if prefix && !url.match?(/[\s<>"'\[\]()]/)
            prefixes << prefix
          else
            literals << url
          end
        end
        if prefixes.any?
          starts = Regexp.union(prefixes.sort_by { |prefix| -prefix.length })
          @media_candidates = %r{(?<![\w/.:])(?:#{starts})[^\s<>"'\[\]()]++}
        else
          @media_candidates = nil
        end
        if literals.any?
          urls = Regexp.union(literals.sort_by { |url| -url.length })
          @literal_media_urls = %r{(?<![\w/.:])(?:#{urls})(?![\w/.%\-])}
        end
      end
      text = text.gsub(@literal_media_urls) { |url| @media_urls.fetch(url) } if @literal_media_urls
      return text unless @media_candidates

      # Scan URL-shaped tokens once. A hash lookup avoids trying every known
      # original and thumbnail against every character in each post.
      text.gsub(@media_candidates) do |url|
        replacement = @media_urls[url]
        next replacement if replacement
        boundaries = []
        url.scan(%r{[^\w/.%\-]}) { boundaries << Regexp.last_match.begin(0) }
        boundaries.reverse_each do |index|
          target = @media_urls[url[0...index]]
          if target
            replacement = target + url[index..]
            break
          end
        end
        replacement || url
      end
    end

    def revision(
      value,
      maps,
      excluded_groups:,
      namespace:,
      source_revision_id:,
      missing_users: Set.new
    )
      metadata(
        GroupMapping.preserve_metadata(value, excluded_groups, namespace),
        maps,
        missing_users: missing_users,
      ) { |text| rewrite(text, source_revision_id: source_revision_id) }
    end

    def metadata(value, maps, missing_users: nil, &rewrite_text)
      case value
      when Array
        value.map { |item| metadata(item, maps, missing_users: missing_users, &rewrite_text) }
      when Hash
        value.to_h do |key, item|
          kind =
            {
              "topic_id" => :topics,
              "target_topic_id" => :topics,
              "post_id" => :posts,
              "target_post_id" => :posts,
              "user_id" => :users,
              "acting_user_id" => :users,
              "group_id" => :groups,
              "upload_id" => :uploads,
              "category_id" => :categories,
            }[
              key
            ]
          if kind && item.is_a?(Array)
            [
              key,
              item.map do |reference|
                if reference.nil?
                  nil
                else
                  metadata(
                    { key => reference },
                    maps,
                    missing_users: missing_users,
                    &rewrite_text
                  ).fetch(key)
                end
              end,
            ]
          elsif kind && item.to_s.match?(/\A-?\d+\z/)
            mapped = maps.fetch(kind)[item.to_i]
            if mapped.nil? && kind == :users && missing_users
              missing_users << item.to_i
              mapped = -1
            end
            raise Error, "Unmapped metadata reference #{key}:#{item}" if mapped.nil?
            [key, mapped]
          elsif %w[username acting_username display_username].include?(key) && item.is_a?(String)
            [key, @usernames[item.downcase] || item]
          else
            [key, metadata(item, maps, missing_users: missing_users, &rewrite_text)]
          end
        end
      when String
        rewrite_text ? rewrite_text.call(value) : rewrite(value)
      else
        value
      end
    end
  end
end
