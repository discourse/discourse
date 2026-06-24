# frozen_string_literal: true

module Migrations
  module Importer
    # The import-time counterpart of `EmbedBuffer`. It swaps the tokens left in
    # `post.raw` back to real Markdown, now that the `original_id -> discourse_id`
    # maps exist.
    #
    # It loads every linkage row for a batch of posts once (one query per kind),
    # then rewrites the bodies in memory. No SQL runs while substituting.
    #
    # ## The `maps` object
    #
    # Rendering needs the built import maps. They are passed in as one object so the
    # resolver does no database work while substituting and stays easy to test. It
    # must respond to:
    #
    #   * `user(original_id)`            => `{ username:, name: }` or `nil`
    #   * `group_name(original_id)`      => `String` or `nil`
    #   * `post(original_id)`            => `{ topic_id:, post_number: }` or `nil`
    #   * `topic_id(original_id)`        => discourse topic id or `nil`
    #   * `upload_markdown(original_id)` => upload Markdown or `nil`
    #   * `poll_markdown(original_id)`   => poll Markdown or `nil`
    #   * `event_markdown(original_id)`  => event Markdown or `nil`
    #   * `base_url`                     => the destination site's base URL
    #
    # ## Reporting
    #
    # A missing lookup falls back to the source value. Uploads, polls and events
    # have no source value to fall back to: when the map can't resolve one, the
    # embed disappears. Each is sent to {#unresolved_sink}.
    #
    # A token with no linkage row at all is an orphan — the convert-time pairing of
    # token and row broke upstream. It is stripped (so no U+E000 character reaches
    # the post) and sent to {#orphan_sink}. The unresolved reporting cannot see this
    # case, because there is no row behind it.
    class PlaceholderResolver
      # An embed whose entity the maps couldn't resolve. Its token becomes an empty
      # string, so this record is the only trace left. `post_url` is the post's URL,
      # or `nil` if the post is not mapped.
      UnresolvedEmbed = Data.define(:kind, :entity_id, :post_id, :post_url)

      # A token with no linkage row. `kind` is parsed from the token, so a report can
      # name what went missing. It matters most for quotes: stripping the opening-tag
      # token leaves the `[/quote]` behind (see #render_quote).
      OrphanPlaceholder = Data.define(:kind, :post_id, :post_url, :placeholder)

      TABLES = {
        quote: "post_quotes",
        link: "post_links",
        mention: "post_mentions",
        poll: "post_polls",
        event: "post_events",
        upload: "post_uploads",
      }.freeze
      private_constant :TABLES

      # Where unresolved embeds and orphan tokens go. Each is the sink passed to the
      # constructor — anything that responds to `<<`. By default an Array you can read
      # back after the run. For a large run, pass a sink that writes straight to disk,
      # so a systemic failure (say, every upload unresolved) does not keep one record
      # per embed in memory.
      attr_reader :unresolved_sink, :orphan_sink

      # @param maps see the class description for the methods it must answer.
      # @param unresolved_sink [#<<] collects {UnresolvedEmbed}s.
      # @param orphan_sink [#<<] collects {OrphanPlaceholder}s.
      def initialize(intermediate_db, maps, unresolved_sink: [], orphan_sink: [])
        @intermediate_db = intermediate_db
        @maps = maps
        @unresolved_sink = unresolved_sink
        @orphan_sink = orphan_sink
      end

      # @param posts [Array<Hash>] each with `:id` (the source post original_id) and `:raw`.
      # @return [Hash{Object => String}] source post id => resolved raw.
      def resolve_all(posts)
        linkages = load_linkages(posts.map { |post| post[:id] })

        posts.each_with_object({}) do |post, result|
          body = substitute(post[:raw], linkages[post[:id]])
          result[post[:id]] = strip_orphans(body, post[:id])
        end
      end

      private

      # Rewrites the tokens in one body in a single `gsub` pass, so the cost does not
      # grow with the number of embeds.
      #
      # The block form is required. With a string replacement, `gsub` reads `\1`,
      # `\0` etc. in the rendered Markdown as backreferences and drops backslashes,
      # which corrupts user content. The block copies the text unchanged.
      #
      # `linkage_rows` is a list of `[kind, row]` pairs (see #load_linkages): each
      # row needs its kind, and the kind is not stored on the row.
      def substitute(raw, linkage_rows)
        return raw if raw.nil? || linkage_rows.nil? || linkage_rows.empty?

        by_placeholder = linkage_rows.to_h { |kind, row| [row[:placeholder], [kind, row]] }

        # A token with no row is left alone here; strip_orphans handles it.
        raw.gsub(Migrations::Placeholder::PATTERN) do |token|
          kind, row = by_placeholder[token]
          kind ? render(kind, row) : token
        end
      end

      # Strips any token left after substitution (it had no linkage row) and records
      # it. When there is no leftover token, the usual case, this is one cheap check.
      def strip_orphans(body, source_post_id)
        return body unless body && Migrations::Placeholder.include?(body)

        post_url = post_url_for(source_post_id)
        Migrations::Placeholder
          .scan(body)
          .each do |token|
            @orphan_sink << OrphanPlaceholder.new(
              kind: Migrations::Placeholder.kind(token),
              post_id: source_post_id,
              post_url:,
              placeholder: token,
            )
          end

        body.gsub(Migrations::Placeholder::PATTERN, "")
      end

      # One query per kind, grouped by post id. The only place that reads the database.
      def load_linkages(post_ids)
        buckets = Hash.new { |hash, key| hash[key] = [] }
        return buckets if post_ids.empty?

        bind_params = (["?"] * post_ids.size).join(", ")

        TABLES.each do |kind, table|
          sql = "SELECT * FROM #{table} WHERE post_id IN (#{bind_params})"
          @intermediate_db.query(sql, *post_ids) { |row| buckets[row[:post_id]] << [kind, row] }
        end

        buckets
      end

      def render(kind, row)
        case kind
        when :quote
          render_quote(row)
        when :link
          render_link(row)
        when :mention
          render_mention(row)
        when :poll, :event, :upload
          render_entity(kind, row)
        end
      end

      # Embeds whose Markdown comes from the maps. No map hit means no fallback, so
      # the embed drops out (empty string) and is recorded.
      def render_entity(kind, row)
        entity_id, markdown =
          case kind
          when :poll
            [row[:poll_id], @maps.poll_markdown(row[:poll_id])]
          when :event
            [row[:event_id], @maps.event_markdown(row[:event_id])]
          when :upload
            [row[:upload_id], @maps.upload_markdown(row[:upload_id])]
          end

        return markdown if markdown.present?

        @unresolved_sink << UnresolvedEmbed.new(
          kind:,
          entity_id:,
          post_id: row[:post_id],
          post_url: post_url_for(row[:post_id]),
        )
        ""
      end

      # The token replaces the opening `[quote="…"]` tag only, the part that needs
      # resolved ids. The quoted text, the closing `[/quote]`, and the blank lines
      # that make it a block are plain text the cooker writes into the raw. None of
      # that enters the linkage table or is touched here. So if a quote token is ever
      # orphaned and stripped, its `[/quote]` is left behind.
      def render_quote(row)
        user = row[:quoted_user_id] ? @maps.user(row[:quoted_user_id]) : nil
        username = user&.fetch(:username, nil) || row[:quoted_username]
        name = user&.fetch(:name, nil)

        if row[:quoted_post_id] && (post = @maps.post(row[:quoted_post_id]))
          topic_id = post[:topic_id]
          post_number = post[:post_number]
        end

        return "[quote]" if username.blank? && name.blank?

        parts = []
        parts << (name.presence || username)
        parts << "post:#{post_number}" if post_number.present?
        parts << "topic:#{topic_id}" if topic_id.present?
        parts << "username:#{username}" if username.present? && name.present?

        "[quote=\"#{parts.join(", ")}\"]"
      end

      def render_link(row)
        url =
          if row[:target_topic_id]
            (topic_id = @maps.topic_id(row[:target_topic_id])) ? topic_url(topic_id) : row[:url]
          elsif row[:target_post_id] && (post = @maps.post(row[:target_post_id]))
            post[:topic_id] && post[:post_number] ? post_url(post) : row[:url]
          else
            row[:url]
          end

        row[:text] ? "[#{row[:text]}](#{url})" : url.to_s
      end

      def render_mention(row)
        name =
          case row[:mention_type]
          when Migrations::MentionType::HERE
            Migrations::MentionType::HERE
          when Migrations::MentionType::ALL
            Migrations::MentionType::ALL
          when Migrations::MentionType::GROUP
            @maps.group_name(row[:target_id]) || row[:name]
          else # USER, or an unspecified (nil) mention
            @maps.user(row[:target_id])&.fetch(:username, nil) || row[:name]
          end

        name.present? ? " @#{name} " : ""
      end

      def topic_url(topic_id)
        "#{@maps.base_url}/t/#{topic_id}"
      end

      def post_url(post)
        "#{@maps.base_url}/t/#{post[:topic_id]}/#{post[:post_number]}"
      end

      # The URL of the post a token sits in, for reporting. `nil` if the post is not
      # mapped (it normally is by the time we substitute).
      def post_url_for(source_post_id)
        post = @maps.post(source_post_id)
        post && post[:topic_id] && post[:post_number] ? post_url(post) : nil
      end
    end
  end
end
