# frozen_string_literal: true

module Migrations
  module Importer
    # The import-time counterpart of `EmbedBuffer`: swaps the tokens left in an
    # owner's markdown back to real Markdown, now that the `original_id ->
    # discourse_id` maps exist. One resolver serves one owner kind.
    #
    # Linkage rows are loaded and their by-name and by-coordinate references
    # resolved ({NameResolver}) in the load phase; no SQL runs while
    # substituting.
    #
    # The contract on a miss is verbatim restore: every row carries the exact
    # source substring it replaced, and an unresolved reference renders those
    # bytes unchanged. A hit rewrites as little as the row allows — links splice
    # only their recorded destination (and self-link label) spans, so titles,
    # angle brackets and padding survive. A canonical rebuild happens only when
    # something actually resolved, or for rows without a verbatim source.
    #
    # An unresolvable poll or event has no source value to fall back to and
    # disappears from the body; a token with no linkage row at all is stripped,
    # so no U+E000 character reaches the owner's markdown.
    #
    # ## The `maps` object
    #
    # The built import maps arrive as one object whose methods must all answer
    # from memory: the render path calls them once per token, and that is what
    # keeps SQL out of substitution. Each answers nil when the destination has
    # no such record.
    #
    #   * `user(id)` => `{ username:, name: }`, `post(id)` => `{ topic_id:,
    #     post_number: }`, `badge(id)` => `{ id:, slug: }`
    #   * `group_name(id)`, `tag_name(id)`, `topic_id(id)`, `category_id(id)`,
    #     `category_slug_path(id)` (`"slug"` or `"parent:child"`)
    #   * `upload_markdown(id)`, `poll_markdown(id)`, `event_markdown(id)`
    #   * `emoji_name(name)`, keyed {NameNormalizer}-folded because a conflict
    #     may have renamed the emoji
    #   * `base_url` and `here_mention`, the destination's own values
    class PlaceholderResolver
      # An embed whose entity the maps couldn't resolve. A poll's or event's
      # token becomes an empty string, so this record is its only trace.
      UnresolvedEmbed = Data.define(:kind, :entity_id, :owner_id, :owner_url)

      # `kind` is parsed from the token, so a report can name what went missing
      # — it matters most for quotes, where stripping the opening-tag token
      # leaves the `[/quote]` behind.
      OrphanPlaceholder = Data.define(:kind, :owner_id, :owner_url, :placeholder)

      Enums = Migrations::Database::IntermediateDB::Enums
      private_constant :Enums

      TAG_SUBCATEGORY_FILTERS = %w[none all]
      private_constant :TAG_SUBCATEGORY_FILTERS

      # Anything that responds to `<<`. For a large run, pass an object that
      # writes straight to disk, so a systemic failure does not keep one record
      # per embed in memory.
      attr_reader :unresolved_embeds, :orphan_placeholders

      # @param maps see the class description for the methods it must answer.
      # @param trusted_upload_hosts [Enumerable<String>] external hosts whose
      #   upload URLs belong to the source site, such as its CDN. Only their
      #   recorded upload ids may use the imported upload map.
      def initialize(
        intermediate_db,
        maps,
        owner_type:,
        trusted_upload_hosts: [],
        unresolved_embeds: [],
        orphan_placeholders: []
      )
        @maps = maps
        @owner_type = owner_type
        @unresolved_embeds = unresolved_embeds
        @orphan_placeholders = orphan_placeholders
        @trusted_upload_hosts = trusted_upload_hosts.map { |host| host.to_s.downcase }.to_set
        @linkages = PlaceholderLinkages.new(intermediate_db)
      end

      # @param items [Array<Hash>] each with `:id` (the owner's original_id) and
      #   `:raw`.
      # @return [Hash{Object => String}] owner original_id => resolved raw.
      def resolve_all(items)
        # An owner with no token in its raw has no embeds, and most bodies are
        # plain text, so this skips the linkage queries for the bulk of a batch.
        with_embeds =
          items.select { |item| item[:raw]&.include?(Migrations::Placeholder::DELIMITER) }
        linkages =
          @linkages.load_and_resolve(with_embeds.map { |item| item[:id] }, owner_type: @owner_type)

        items.each_with_object({}) do |item, result|
          body = substitute(item[:raw], linkages[item[:id]])
          result[item[:id]] = strip_orphans(body, item[:id])
        end
      end

      private

      # The block form is required: with a string replacement, `gsub` reads
      # `\1`, `\0` etc. in the rendered Markdown as backreferences and drops
      # backslashes, which corrupts user content.
      def substitute(raw, linkage_rows)
        return raw if raw.nil? || linkage_rows.blank?

        by_placeholder = linkage_rows.to_h { |kind, row| [row[:placeholder], [kind, row]] }

        # A token with no row is left alone here; strip_orphans handles it.
        raw.gsub(Migrations::Placeholder::PATTERN) do |token|
          kind, row = by_placeholder[token]
          kind ? render(kind, row) : token
        end
      end

      def strip_orphans(body, owner_id)
        return body unless body && Migrations::Placeholder.include?(body)

        owner_url = owner_url_for(owner_id)
        Migrations::Placeholder
          .scan(body)
          .each do |token|
            @orphan_placeholders << OrphanPlaceholder.new(
              kind: Migrations::Placeholder.kind(token),
              owner_id:,
              owner_url:,
              placeholder: token,
            )
          end

        body.gsub(Migrations::Placeholder::PATTERN, "")
      end

      def render(kind, row)
        case kind
        when :quote
          render_quote(row)
        when :link
          render_link(row)
        when :mention
          render_mention(row)
        when :hashtag
          render_hashtag(row)
        when :emoji
          render_emoji(row)
        when :poll, :event, :upload
          render_entity(kind, row)
        end
      end

      def render_entity(kind, row)
        entity_id, markdown =
          case kind
          when :poll
            [row[:poll_id], @maps.poll_markdown(row[:poll_id])]
          when :event
            [row[:event_id], @maps.event_markdown(row[:event_id])]
          when :upload
            [row[:upload_id], resolve_upload(row)]
          end

        return markdown if markdown.present?

        # The report is the only signal this entity needs attention.
        @unresolved_embeds << UnresolvedEmbed.new(
          kind:,
          entity_id:,
          owner_id: row[:owner_id],
          owner_url: owner_url_for(row[:owner_id]),
        )

        # An upload row carries the verbatim source snippet, so a hotlink to
        # another forum's upload survives. Polls and events have no fallback.
        kind == :upload ? row[:original_markdown].to_s : ""
      end

      # A foreign 40-hex basename could collide with a source upload sha1 and
      # rewrite another site's file, so an unrecognized host's row is mapped
      # only when the operator trusts that host as source upload storage.
      def resolve_upload(row)
        external_host = row[:external_host]
        return nil if external_host && !@trusted_upload_hosts.include?(external_host.downcase)

        @maps.upload_markdown(row[:upload_id])
      end

      # Builds the opening `[quote="…"]` tag only (see EmbedBuffer#quote). A
      # canonical rebuild is only warranted when something actually resolved; a
      # full miss restores the verbatim source tag, which may carry syntax the
      # reference columns don't model (casing, spacing, parameters core
      # ignores). Recorded post coordinates that don't resolve take that
      # fallback too, however well the quoted user resolved: rendering the user
      # alone would turn a quote of one specific post into a bare attribution.
      def render_quote(row)
        user = row[:quoted_user_id] ? @maps.user(row[:quoted_user_id]) : nil
        username = user&.dig(:username) || row[:quoted_username]
        name = user&.dig(:name) || row[:quoted_name]

        post = row[:quoted_post_id] ? @maps.post(row[:quoted_post_id]) : nil
        topic_id = post&.dig(:topic_id)
        post_number = post&.dig(:post_number)

        lost_coordinates = quoted_post_recorded?(row) && !(topic_id && post_number)
        report_unresolved_quote(row) if lost_coordinates

        if row[:original_markdown].present? && (lost_coordinates || (user.nil? && post.nil?))
          return row[:original_markdown]
        end

        parts = [name.presence || username.presence]
        parts << "post:#{post_number}" if post_number.present?
        parts << "topic:#{topic_id}" if topic_id.present?
        parts << "username:#{username}" if username.present? && name.present? && name != username

        return "[quote]" if parts.compact.empty?

        # Core reads the first segment as the username, so it would attribute
        # `[quote="post:4, topic:9"]` to a user named "post:4".
        "[quote=\"#{parts.join(", ")}\"]"
      end

      # Any of the three columns counts: a pair the source posts don't have and
      # a lone coordinate are both unresolvable, and both would vanish.
      def quoted_post_recorded?(row)
        row[:quoted_post_id].present? || row[:quoted_topic_id].present? ||
          row[:quoted_post_number].present?
      end

      def report_unresolved_quote(row)
        entity_id = row[:quoted_post_id] || quoted_coordinates(row)

        @unresolved_embeds << UnresolvedEmbed.new(
          kind: :quote,
          entity_id:,
          owner_id: row[:owner_id],
          owner_url: owner_url_for(row[:owner_id]),
        )
      end

      def quoted_coordinates(row)
        [
          ("topic:#{row[:quoted_topic_id]}" if row[:quoted_topic_id].present?),
          ("post:#{row[:quoted_post_number]}" if row[:quoted_post_number].present?),
        ].compact.join(", ")
      end

      # An unresolvable internal link falls back to the source URL AND reports
      # it. This diverges from the mention/hashtag no-report convention on
      # purpose: on a merge into an existing site a stale `/t/slug/123` doesn't
      # 404, it silently points at the WRONG topic. A `SITE` link only has its
      # origin rewritten, so it always resolves and is never reported.
      def render_link(row)
        return render_link_markup(row, row[:url]) unless row[:target_type]
        return render_site_link(row) if row[:target_type] == Enums::LinkTarget::SITE

        url =
          if multi_tag_link?(row)
            rebuild_multi_tag_link(row)
          else
            row[:target_id] && rebuild_internal_link(row)
          end
        return render_link_markup(row, url) if url

        report_unresolved_link(row)
        render_link_markup(row, row[:url])
      end

      def render_site_link(row)
        render_link_markup(row, "#{@maps.base_url}#{row[:target_suffix]}")
      end

      def multi_tag_link?(row)
        row[:target_type] == Enums::LinkTarget::CATEGORY_TAG ||
          row[:target_type] == Enums::LinkTarget::TAG_INTERSECTION
      end

      def tag_path_filter(row)
        return nil unless row[:target_type] == Enums::LinkTarget::CATEGORY_TAG

        segments = row[:target_tag_path].to_s.split("/")
        return nil unless segments.size > 1

        TAG_SUBCATEGORY_FILTERS.include?(segments.first) ? segments.first : nil
      end

      # Rewrites only the destination inside the verbatim source construct, so
      # titles, angle brackets and padding survive and an unchanged URL
      # round-trips byte-exact. Every spelling of the source URL inside the
      # construct is a destination spelling (a `[URL](URL)` self-link shows it
      # twice), so all are rewritten.
      def render_link_markup(row, url)
        original = row[:original_markdown]
        if original.present?
          return original if url == row[:url]

          spans = destination_spans(row, original)
          return splice_url_spans(original, spans, url) if spans
        end

        # An empty recorded text renders as a bare URL rather than `[](url)`.
        # Also the path for a row with a snippet but no destination span: a
        # value search would rewrite the URL wherever else the author typed it.
        text = row[:text].presence
        text ? "[#{text}](#{url})" : url.to_s
      end

      # The destination's recorded byte span(s) inside the verbatim snippet, or
      # nil when the row carries none or a span is wrong. The bytes at the
      # offset must equal the row's URL: an offset that is in bounds but points
      # elsewhere would splice the destination into arbitrary syntax.
      def destination_spans(row, original)
        offset = row[:url_offset]
        return nil if offset.nil? || row[:url].blank?

        url = row[:url]
        length = url.bytesize
        return nil unless span_holds_url?(original, offset, url)

        spans = [offset]
        label = row[:label_url_offset]
        spans << label if label && label != offset && span_holds_url?(original, label, url)
        spans.sort.map { |span_offset| [span_offset, length] }
      end

      # A negative offset would read from the end, and rows come from a
      # database.
      def span_holds_url?(original, offset, url)
        offset >= 0 && original.byteslice(offset, url.bytesize) == url
      end

      def splice_url_spans(original, spans, url)
        result = original.dup
        spans.reverse_each { |offset, length| result.bytesplice(offset, length, url) }
        result
      end

      # The destination URL for a resolved internal link, or nil on a maps miss.
      # The suffix is appended by the caller's success path, so a miss can
      # report cleanly.
      def rebuild_internal_link(row)
        base = internal_link_base(row)
        base && "#{base}#{row[:target_suffix]}"
      end

      def internal_link_base(row)
        target_id = row[:target_id]

        case row[:target_type]
        when Enums::LinkTarget::TOPIC
          (topic_id = @maps.topic_id(target_id)) && topic_url(topic_id)
        when Enums::LinkTarget::POST
          post = @maps.post(target_id)
          post && post[:topic_id] && post[:post_number] && post_url(post)
        when Enums::LinkTarget::USER
          (user = @maps.user(target_id)) && (username = user[:username]) &&
            "#{@maps.base_url}/u/#{username}"
        when Enums::LinkTarget::GROUP
          (name = @maps.group_name(target_id)) && "#{@maps.base_url}/g/#{name}"
        when Enums::LinkTarget::TAG
          (name = @maps.tag_name(target_id)) && "#{@maps.base_url}/tag/#{name}"
        when Enums::LinkTarget::CATEGORY
          category_link_url(target_id)
        when Enums::LinkTarget::BADGE
          badge_link_url(target_id)
        end
      end

      # `/c/<slug path>/<id>`, with the slug path's `:` separators turned back
      # into `/`.
      def category_link_url(target_id)
        parts = category_route_parts(target_id)
        parts && "#{@maps.base_url}/c/#{parts}"
      end

      # `<slug path>/<id>` for the destination category — the shared middle of
      # the `/c/…` and `/tags/c/…` routes. Nil when the category isn't mapped.
      def category_route_parts(target_id)
        return nil unless target_id

        new_id = @maps.category_id(target_id)
        path = @maps.category_slug_path(target_id)
        new_id && path && "#{path.tr(":", "/")}/#{new_id}"
      end

      # The destination URL for a multi-tag route. Nil when any coordinate
      # didn't map, because a route naming several records is only rebuilt
      # whole.
      def rebuild_multi_tag_link(row)
        tag_ids = row[:resolved_tag_ids]
        return nil unless tag_ids

        names = tag_ids.map { |id| @maps.tag_name(id) }
        return nil unless names.all?

        base =
          case row[:target_type]
          when Enums::LinkTarget::TAG_INTERSECTION
            "#{@maps.base_url}/tags/intersection/#{names.join("/")}"
          when Enums::LinkTarget::CATEGORY_TAG
            parts = category_route_parts(row[:target_id])
            tag_path = [tag_path_filter(row), names.first].compact.join("/")
            parts && "#{@maps.base_url}/tags/c/#{parts}/#{tag_path}"
          end
        base && "#{base}#{row[:target_suffix]}"
      end

      def badge_link_url(target_id)
        badge = @maps.badge(target_id)
        badge && "#{@maps.base_url}/badges/#{badge[:id]}/#{badge[:slug]}"
      end

      def report_unresolved_link(row)
        # A coordinate-form post link has neither a target id nor a name, so the
        # original URL is the most useful thing a report can name it by.
        @unresolved_embeds << UnresolvedEmbed.new(
          kind: :link,
          entity_id: row[:target_id] || row[:target_name] || row[:url],
          owner_id: row[:owner_id],
          owner_url: owner_url_for(row[:owner_id]),
        )
      end

      def render_mention(row)
        name =
          case row[:mention_type]
          when Enums::MentionType::HERE
            # Here-matching is case-insensitive at cook time, so the author's
            # own spelling works as-is — only a different name is a remap.
            here = @maps.here_mention.presence
            if here && (row[:name].blank? || !here.casecmp?(row[:name]))
              here
            else
              row[:name].presence || "here"
            end
          when Enums::MentionType::ALL
            row[:name].presence || "all"
          when Enums::MentionType::GROUP
            @maps.group_name(row[:target_id]) || row[:name]
          else # USER, or an unspecified (nil) mention
            @maps.user(row[:target_id])&.dig(:username) || row[:name]
          end

        # The token spans exactly the original `@name`, so the surrounding text
        # is already intact.
        return "@#{name}" if name.present?

        # Nearly unreachable, but an embed may only vanish with a report.
        @unresolved_embeds << UnresolvedEmbed.new(
          kind: :mention,
          entity_id: row[:target_id] || row[:name],
          owner_id: row[:owner_id],
          owner_url: owner_url_for(row[:owner_id]),
        )
        row[:original_markdown].to_s
      end

      # A resolved tag renders as `#<name>::tag` always: a bare `#name` resolves
      # category-first at import, so a destination category sharing the slug
      # would otherwise hijack an unsuffixed tag. No unresolved report — the
      # source value is the fallback, as with mentions.
      def render_hashtag(row)
        if row[:target_id]
          case row[:hashtag_type]
          when Enums::HashtagType::CATEGORY
            path = @maps.category_slug_path(row[:target_id])
            return "##{path}" if path
          when Enums::HashtagType::TAG
            name = @maps.tag_name(row[:target_id])
            return "##{name}::tag" if name
          end
        end

        # A bare `#name` must stay bare even when the import resolved a type it
        # then couldn't render: the mutated `hashtag_type` must not leak a
        # suffix the source never had.
        row[:original_markdown].presence || rebuild_hashtag(row)
      end

      # Rebuilds the source `#name` for a row without a verbatim source, adding
      # back the suffix the `hashtag_type` implies.
      def rebuild_hashtag(row)
        suffix =
          case row[:hashtag_type]
          when Enums::HashtagType::CATEGORY
            "::category"
          when Enums::HashtagType::TAG
            "::tag"
          else
            ""
          end

        "##{row[:name]}#{suffix}"
      end

      # The lookup folds the way {NameResolver}'s name lookups do, because the
      # row keeps the author's spelling (`:MYEMOJI:`) while core lowercases a
      # shortcode first. No unresolved report — the source name is the fallback.
      def render_emoji(row)
        name = @maps.emoji_name(Migrations::NameNormalizer.normalize(row[:name])) || row[:name]
        ":#{name}:"
      end

      def topic_url(topic_id)
        "#{@maps.base_url}/t/#{topic_id}"
      end

      def post_url(post)
        "#{@maps.base_url}/t/#{post[:topic_id]}/#{post[:post_number]}"
      end

      # Nil when the owning record is not mapped.
      def owner_url_for(owner_id)
        case @owner_type
        when Enums::EmbedOwner::POST
          post = @maps.post(owner_id)
          post && post[:topic_id] && post[:post_number] ? post_url(post) : nil
        when Enums::EmbedOwner::USER
          username = @maps.user(owner_id)&.dig(:username)
          username ? "#{@maps.base_url}/u/#{username}" : nil
        end
      end
    end
  end
end
