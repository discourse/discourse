# frozen_string_literal: true

module Migrations
  module Importer
    # The import-time counterpart of `EmbedBuffer`. It swaps the tokens left in an
    # owner's markdown back to real Markdown, now that the `original_id ->
    # discourse_id` maps exist. One resolver instance serves one owner kind
    # (`owner_type`); currently the owner is always a post, later this will also
    # cover user bios and other records.
    #
    # It loads every linkage row for a batch of owners with bounded queries,
    # resolves the references the converter could only record by source coordinates
    # or by name (a quoted post, a quoted user, a mentioned user or group), and then
    # rewrites the bodies in memory. All of that runs in the load phase; no SQL runs
    # while substituting. Turning a recorded name into a source id is delegated to
    # {NameResolver}.
    #
    # The contract on a miss is verbatim restore: every row carries the exact
    # source substring it replaced, and an unresolved reference renders those
    # bytes unchanged. A hit rewrites as little as the row allows — links splice
    # only their recorded destination (and self-link label) spans, so titles,
    # angle brackets and padding survive; a canonical rebuild happens only when
    # something actually resolved, or for rows without a verbatim source.
    #
    # ## The `maps` object
    #
    # Rendering needs the built import maps. They are passed in as one object so the
    # resolver does no database work while substituting and stays easy to test.
    # Every method must answer from memory — no SQL, no I/O: the render path calls
    # the maps once per token, and the no-queries-while-substituting guarantee
    # holds only if the maps keep it too. It must respond to:
    #
    #   * `user(original_id)`               => `{ username:, name: }` or `nil`
    #   * `group_name(original_id)`         => `String` or `nil`
    #   * `post(original_id)`               => `{ topic_id:, post_number: }` or `nil`
    #   * `topic_id(original_id)`           => discourse topic id or `nil`
    #   * `upload_markdown(original_id)`    => upload Markdown or `nil`
    #   * `poll_markdown(original_id)`      => poll Markdown or `nil`
    #   * `event_markdown(original_id)`     => event Markdown or `nil`
    #   * `category_slug_path(original_id)` => the destination category's slug path,
    #                                          `"slug"` or `"parent:child"`, or `nil`
    #   * `category_id(original_id)`        => the destination category id or `nil`
    #                                          (an internal `/c/…` link needs the id,
    #                                          not just the slug path)
    #   * `tag_name(original_id)`           => the destination tag's name or `nil`
    #   * `badge(original_id)`              => `{ id:, slug: }` for the destination
    #                                          badge, or `nil`
    #   * `emoji_name(source_name)`         => the destination custom emoji name (a
    #                                          conflict may rename it) or `nil`. The
    #                                          name comes in {NameNormalizer}-folded,
    #                                          so the map must key it the same way
    #   * `base_url`                        => the destination site's base URL
    #   * `here_mention`                    => the destination's `here_mention` site
    #                                          setting value (the name that acts as the
    #                                          "@here" mention)
    #
    # ## Reporting
    #
    # A missing lookup falls back to the source value. Polls and events have no
    # source value to fall back to: when the map can't resolve one, the embed
    # disappears. An upload keeps its verbatim source snippet (both `upload://`
    # and full-URL forms record one), so a miss restores it unchanged. Each
    # miss is sent to {#unresolved_embeds}.
    #
    # An internal link that can't be resolved does have a fallback (its source URL),
    # but it is still reported: a stale internal link points at the wrong record
    # rather than failing loudly, so operators need the report (see #render_link).
    # A quote whose recorded post coordinates don't resolve is reported for the
    # same reason (see #render_quote).
    #
    # A token with no linkage row at all is an orphan — the token and its row were
    # not written together upstream. It is stripped (so no U+E000 character reaches
    # the owner's markdown) and sent to {#orphan_placeholders}. The unresolved reporting
    # can't see this case, because there is no row behind it.
    class PlaceholderResolver
      # An embed whose entity the maps couldn't resolve. A poll's or event's
      # token becomes an empty string, so this record is its only trace; an
      # upload's token becomes the verbatim source snippet again. `owner_url`
      # is the owning record's URL, or `nil` if it is not mapped.
      UnresolvedEmbed = Data.define(:kind, :entity_id, :owner_id, :owner_url)

      # A token with no linkage row. `kind` is parsed from the token, so a report can
      # name what went missing. It matters most for quotes: stripping the opening-tag
      # token leaves the `[/quote]` behind (see #render_quote).
      OrphanPlaceholder = Data.define(:kind, :owner_id, :owner_url, :placeholder)

      Enums = Migrations::Database::IntermediateDB::Enums
      private_constant :Enums

      TAG_SUBCATEGORY_FILTERS = %w[none all]
      private_constant :TAG_SUBCATEGORY_FILTERS

      # Where unresolved embeds and orphan tokens are reported. Each is whatever was
      # passed to the constructor — anything that responds to `<<`. By default an Array
      # you can read back after the run. For a large run, pass an object that writes
      # straight to disk, so a systemic failure (say, every upload unresolved) does not
      # keep one record per embed in memory.
      attr_reader :unresolved_embeds, :orphan_placeholders

      # @param owner_type [Integer] the owner kind this resolver serves, an
      #   `Enums::EmbedOwner` value (e.g. `EmbedOwner::POST`).
      # @param maps see the class description for the methods it must answer.
      # @param unresolved_embeds [#<<] collects {UnresolvedEmbed}s.
      # @param orphan_placeholders [#<<] collects {OrphanPlaceholder}s.
      def initialize(
        intermediate_db,
        maps,
        owner_type:,
        unresolved_embeds: [],
        orphan_placeholders: []
      )
        @maps = maps
        @owner_type = owner_type
        @unresolved_embeds = unresolved_embeds
        @orphan_placeholders = orphan_placeholders
        @linkages = PlaceholderLinkages.new(intermediate_db)
      end

      # @param items [Array<Hash>] each with `:id` (the owner's original_id) and `:raw`.
      # @return [Hash{Object => String}] owner original_id => resolved raw.
      def resolve_all(items)
        # An owner with no token in its raw has no embeds (the token and the row are
        # written together), so there's nothing to load for it. Most bodies are
        # plain text, so this skips the linkage queries for the bulk of a batch.
        # `String#include?` of the one-char delimiter is a `memchr`, far cheaper
        # than querying every linkage table per owner.
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

      # Rewrites the tokens in one body in a single `gsub` pass — one scan of the body
      # instead of one `gsub` per embed.
      #
      # The block form is required. With a string replacement, `gsub` reads `\1`,
      # `\0` etc. in the rendered Markdown as backreferences and drops backslashes,
      # which corrupts user content. The block copies the text unchanged.
      #
      # `linkage_rows` is a list of `[kind, row]` pairs: each
      # row needs its kind, and the kind is not stored on the row.
      def substitute(raw, linkage_rows)
        return raw if raw.nil? || linkage_rows.blank?

        by_placeholder = linkage_rows.to_h { |kind, row| [row[:placeholder], [kind, row]] }

        # A token with no row is left alone here; strip_orphans handles it.
        raw.gsub(Migrations::Placeholder::PATTERN) do |token|
          kind, row = by_placeholder[token]
          kind ? render(kind, row) : token
        end
      end

      # Strips and records any token still here after substitution — it had no
      # linkage row. Usually there's none, so this is just one cheap check.
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
            [row[:upload_id], resolve_upload(row)]
          end

        return markdown if markdown.present?

        # Always report: the report is the only signal this entity needs attention.
        @unresolved_embeds << UnresolvedEmbed.new(
          kind:,
          entity_id:,
          owner_id: row[:owner_id],
          owner_url: owner_url_for(row[:owner_id]),
        )

        # An upload row carries the verbatim source snippet (short `upload://`
        # and full-URL forms alike); put it back rather than dropping it, so a
        # hotlink to another forum's upload (which maps to nothing here)
        # survives. Polls and events have no fallback and drop out.
        kind == :upload ? row[:original_markdown].to_s : ""
      end

      # A row whose URL pointed at a host the conversion didn't recognize is
      # never mapped — a foreign 40-hex basename can collide with a source
      # upload sha1, and mapping it would rewrite another site's file.
      # Declined rows take the verbatim fallback through the caller's miss
      # path.
      def resolve_upload(row)
        return nil if row[:external_host]

        @maps.upload_markdown(row[:upload_id])
      end

      # Builds the opening `[quote="…"]` tag only; the quoted text and `[/quote]` are
      # plain text in the raw (see EmbedBuffer#quote). So an orphaned quote token,
      # once stripped, leaves its `[/quote]` behind.
      #
      # A rebuild is canonical: straight quotes, the known fields, nothing else.
      # That is only warranted when something actually resolved; a full miss
      # restores the verbatim source tag, which may carry syntax the reference
      # columns don't model (casing, spacing, parameters core ignores).
      #
      # Recorded post coordinates that don't resolve take the same fallback and
      # are reported, however well the quoted user resolved: rendering the user
      # alone would turn a quote of one specific post into a bare attribution,
      # and a quote whose `post:`/`topic:` silently disappeared is the same class
      # of wrong-target failure #render_link reports. So the verbatim source tag
      # comes back when the row carries one, and only a row without one is
      # rebuilt from whatever did resolve.
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

        # Coordinates without an author keep the leading segment empty, because
        # core's header parser reads the first segment as the username: it would
        # attribute `[quote="post:4, topic:9"]` to a user named "post:4", while
        # `[quote=", post:4, topic:9"]` keeps the coordinates and no author.
        "[quote=\"#{parts.join(", ")}\"]"
      end

      # Whether the row points at one specific quoted post — by source id, or by
      # the source coordinates the load phase tries to turn into one. Any of the
      # three columns counts: a pair the source posts don't have and a lone
      # coordinate are both unresolvable, and both would vanish from the header.
      def quoted_post_recorded?(row)
        row[:quoted_post_id].present? || row[:quoted_topic_id].present? ||
          row[:quoted_post_number].present?
      end

      def report_unresolved_quote(row)
        # A coordinate-form quote has no post id to name; the coordinates the
        # author's header carried are the most useful identifier for it.
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

      # An external link (no `target_type`) passes through as-is. A `SITE` link points
      # at a route-less page on the source (its `/faq`, a search URL, or junk); only
      # its origin is rewritten to the destination, so it's always resolvable and never
      # reported (see #render_site_link). Any other internal link is rebuilt through the
      # resolved `target_id` and the destination maps, honoring any rename or renumber;
      # whatever trailed the matched route (`target_suffix`) is reattached verbatim. A
      # bare URL stays bare so oneboxes keep working; a link with text keeps its
      # `[text](url)` shape.
      #
      # An internal link that can't be resolved (nil `target_id` after normalization,
      # or a maps miss here) falls back to the source URL AND reports it. This diverges
      # from the mention/hashtag no-report convention on purpose: on a merge into an
      # existing site a stale `/t/slug/123` doesn't 404, it silently points at the
      # WRONG topic, so operators need the audit trail.
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

      # A `SITE` link keeps everything but its origin: the destination base URL plus the
      # source path/query/fragment carried in `target_suffix`. `base_url` is always
      # known, so this resolves for every row and needs no unresolved report.
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
      # titles, angle brackets, padding — syntax the reference columns don't
      # model — survive a rewrite, and an unchanged URL (an external link, or
      # any miss falling back to the source URL) round-trips byte-exact. Every
      # spelling of the source URL inside the construct is a destination
      # spelling (a `[URL](URL)` self-link shows it twice), so all of them are
      # rewritten. Rebuilding `[text](url)` from the columns remains only for
      # rows without a verbatim source.
      def render_link_markup(row, url)
        original = row[:original_markdown]
        if original.present?
          return original if url == row[:url]

          spans = destination_spans(row, original)
          return splice_url_spans(original, spans, url) if spans
        end

        # `presence`: a converter may have recorded an empty text; treat it as
        # a bare URL rather than rendering `[](url)`. Also the path for a row
        # that carries a verbatim snippet but no destination span (a converter
        # that never recorded one): a value search over the snippet would also
        # rewrite the URL wherever else the author typed it — a link title,
        # for one — so the construct is rebuilt canonically instead.
        text = row[:text].presence
        text ? "[#{text}](#{url})" : url.to_s
      end

      # The destination's recorded byte span(s) inside the verbatim snippet —
      # the span itself plus a self-link label's spelling when one was
      # recorded — or nil when the row carries none or a span is wrong. A
      # span must fit the snippet AND the bytes there must equal the row's
      # URL: an offset that is in bounds but points elsewhere would splice
      # the destination into arbitrary syntax, so it falls back to the
      # canonical rebuild instead.
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

      # A negative offset would make `byteslice` read from the end of the
      # snippet; rows come from a database, so the sign is checked here, not
      # assumed.
      def span_holds_url?(original, offset, url)
        offset >= 0 && original.byteslice(offset, url.bytesize) == url
      end

      def splice_url_spans(original, spans, url)
        result = original.dup
        spans.reverse_each { |offset, length| result.bytesplice(offset, length, url) }
        result
      end

      # The destination URL for a resolved internal link, or nil on a maps miss (an
      # entity the destination doesn't have). The suffix is appended by the caller's
      # success path, so a miss can report cleanly.
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

      # `/c/<slug path>/<id>`, with the slug path's `:` separators turned back into
      # `/`. Both the id and the path come from the destination category.
      def category_link_url(target_id)
        parts = category_route_parts(target_id)
        parts && "#{@maps.base_url}/c/#{parts}"
      end

      # `<slug path>/<id>` for the destination category, the shared middle of the
      # `/c/…` and `/tags/c/…` routes; nil when the category isn't mapped.
      def category_route_parts(target_id)
        return nil unless target_id

        new_id = @maps.category_id(target_id)
        path = @maps.category_slug_path(target_id)
        new_id && path && "#{path.tr(":", "/")}/#{new_id}"
      end

      # The destination URL for a multi-tag route, or nil when any coordinate —
      # the category, or any tag — didn't map: a route naming several records is
      # only rebuilt whole.
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
        # A coordinate-form post link has neither a target id nor a name; the
        # original URL is the most useful identifier a report can carry for it.
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
            # The destination decides which name acts as the here-mention, but
            # only an actually different name is a remap. Here-matching is
            # case-insensitive at cook time, so the author's own spelling
            # (`@Here`) works on the destination as-is — canonicalizing it
            # would change bytes for nothing.
            here = @maps.here_mention.presence
            if here && (row[:name].blank? || !here.casecmp?(row[:name]))
              here
            else
              row[:name].presence || "here"
            end
          when Enums::MentionType::ALL
            # `@all` is not a configurable name; with nothing to remap to, the
            # author's spelling survives.
            row[:name].presence || "all"
          when Enums::MentionType::GROUP
            @maps.group_name(row[:target_id]) || row[:name]
          else # USER, or an unspecified (nil) mention
            @maps.user(row[:target_id])&.dig(:username) || row[:name]
          end

        # The token spans exactly the original `@name`, so the surrounding text is
        # already intact — rendering verbatim keeps the source spacing.
        return "@#{name}" if name.present?

        # Nearly unreachable: the converter always records a name. But an embed
        # may only vanish with a report, so record one — and restore the
        # verbatim source when the row carries it, rather than dropping text.
        @unresolved_embeds << UnresolvedEmbed.new(
          kind: :mention,
          entity_id: row[:target_id] || row[:name],
          owner_id: row[:owner_id],
          owner_url: owner_url_for(row[:owner_id]),
        )
        row[:original_markdown].to_s
      end

      # A resolved category renders as `#<slug path>`, honoring any rename or merge
      # the destination applied. A resolved tag renders as `#<name>::tag` always: a
      # bare `#name` resolves category-first at import, so a destination category
      # sharing the slug would otherwise hijack an unsuffixed tag. A map miss or an
      # unresolved row rebuilds the source text, so the original `#name` survives.
      # No unresolved report — the source value is the fallback, as with mentions.
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

        # The verbatim source restores exactly what the author wrote — in
        # particular a bare `#name` stays bare even when the import resolved a
        # type it then couldn't render (the mutated `hashtag_type` must not
        # leak a `::category`/`::tag` suffix the source never had).
        row[:original_markdown].presence || rebuild_hashtag(row)
      end

      # Rebuilds the source `#name` for a row without a verbatim source,
      # re-adding the `::tag`/`::category` suffix the `hashtag_type` implies.
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

      # A custom emoji renders as `:<name>:`, remapped through the emoji-name map in
      # case a conflict renamed it. A map miss puts the source name back verbatim; no
      # unresolved report — the source value is the fallback, as with mentions and
      # hashtags.
      #
      # The lookup folds case and Unicode form the way the name lookups in
      # {NameResolver} do, because the row keeps the author's spelling
      # (`:MYEMOJI:`) while core lowercases a shortcode before looking it up.
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

      # The URL of the record a token sits in, for reporting. `nil` if that record
      # is not mapped (it normally is by the time we substitute).
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
