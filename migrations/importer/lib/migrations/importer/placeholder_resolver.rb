# frozen_string_literal: true

module Migrations
  module Importer
    # The import-time counterpart of `EmbedBuffer`. It swaps the tokens left in an
    # owner's markdown back to real Markdown, now that the `original_id ->
    # discourse_id` maps exist. One resolver instance serves one owner kind
    # (`owner_type`); the owner is a post today, a user bio etc. later.
    #
    # It loads every linkage row for a batch of owners once (one query per kind),
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
    # A token with no linkage row at all is an orphan — the token and its row were
    # not written together upstream. It is stripped (so no U+E000 character reaches
    # the owner's markdown) and sent to {#orphan_sink}. The unresolved reporting
    # can't see this case, because there is no row behind it.
    class PlaceholderResolver
      # An embed whose entity the maps couldn't resolve. Its token becomes an empty
      # string, so this record is the only trace left. `owner_url` is the owning
      # record's URL, or `nil` if it is not mapped.
      UnresolvedEmbed = Data.define(:kind, :entity_id, :owner_id, :owner_url)

      # A token with no linkage row. `kind` is parsed from the token, so a report can
      # name what went missing. It matters most for quotes: stripping the opening-tag
      # token leaves the `[/quote]` behind (see #render_quote).
      OrphanPlaceholder = Data.define(:kind, :owner_id, :owner_url, :placeholder)

      TABLES = {
        quote: "embed_quotes",
        link: "embed_links",
        mention: "embed_mentions",
        poll: "embed_polls",
        event: "embed_events",
        upload: "embed_uploads",
      }.freeze
      private_constant :TABLES

      Enums = Migrations::Database::IntermediateDB::Enums
      private_constant :Enums

      # Where unresolved embeds and orphan tokens go. Each is the sink passed to the
      # constructor — anything that responds to `<<`. By default an Array you can read
      # back after the run. For a large run, pass a sink that writes straight to disk,
      # so a systemic failure (say, every upload unresolved) does not keep one record
      # per embed in memory.
      attr_reader :unresolved_sink, :orphan_sink

      # @param owner_type [Integer] the owner kind this resolver serves, an
      #   `Enums::EmbedOwner` value (e.g. `EmbedOwner::POST`).
      # @param maps see the class description for the methods it must answer.
      # @param unresolved_sink [#<<] collects {UnresolvedEmbed}s.
      # @param orphan_sink [#<<] collects {OrphanPlaceholder}s.
      def initialize(intermediate_db, maps, owner_type:, unresolved_sink: [], orphan_sink: [])
        @intermediate_db = intermediate_db
        @maps = maps
        @owner_type = owner_type
        @unresolved_sink = unresolved_sink
        @orphan_sink = orphan_sink
      end

      # @param items [Array<Hash>] each with `:id` (the owner's original_id) and `:raw`.
      # @return [Hash{Object => String}] owner original_id => resolved raw.
      def resolve_all(items)
        # An owner with no token in its raw has no embeds (the token and the row are
        # written together), so there's nothing to load for it. Most bodies are
        # plain text, so this skips the linkage queries for the bulk of a batch.
        # `String#include?` of the one-char delimiter is a `memchr`, far cheaper
        # than probing six indexes per owner.
        with_embeds =
          items.select { |item| item[:raw]&.include?(Migrations::Placeholder::DELIMITER) }
        linkages = load_linkages(with_embeds.map { |item| item[:id] })

        items.each_with_object({}) do |item, result|
          body = substitute(item[:raw], linkages[item[:id]])
          result[item[:id]] = strip_orphans(body, item[:id])
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
            @orphan_sink << OrphanPlaceholder.new(
              kind: Migrations::Placeholder.kind(token),
              owner_id:,
              owner_url:,
              placeholder: token,
            )
          end

        body.gsub(Migrations::Placeholder::PATTERN, "")
      end

      # One query per kind, grouped by owner id. The only place that reads the database.
      def load_linkages(owner_ids)
        buckets = Hash.new { |hash, key| hash[key] = [] }
        return buckets if owner_ids.empty?

        bind_params = (["?"] * owner_ids.size).join(", ")

        TABLES.each do |kind, table|
          sql = "SELECT * FROM #{table} WHERE owner_type = ? AND owner_id IN (#{bind_params})"
          @intermediate_db.query(sql, @owner_type, *owner_ids) do |row|
            buckets[row[:owner_id]] << [kind, row]
          end
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
          owner_id: row[:owner_id],
          owner_url: owner_url_for(row[:owner_id]),
        )
        ""
      end

      # Builds the opening `[quote="…"]` tag only; the quoted text and `[/quote]` are
      # plain text in the raw (see EmbedBuffer#quote). So an orphaned quote token,
      # once stripped, leaves its `[/quote]` behind.
      def render_quote(row)
        user = row[:quoted_user_id] ? @maps.user(row[:quoted_user_id]) : nil
        username = user&.fetch(:username, nil) || row[:quoted_username]
        name = user&.fetch(:name, nil) || row[:quoted_name]

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
          case row[:target_type]
          when Enums::LinkTarget::TOPIC
            (topic_id = @maps.topic_id(row[:target_id])) ? topic_url(topic_id) : row[:url]
          when Enums::LinkTarget::POST
            post = @maps.post(row[:target_id])
            post && post[:topic_id] && post[:post_number] ? post_url(post) : row[:url]
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

      # The URL of the record a token sits in, for reporting. `nil` if that record
      # is not mapped (it normally is by the time we substitute).
      def owner_url_for(owner_id)
        case @owner_type
        when Enums::EmbedOwner::POST
          post = @maps.post(owner_id)
          post && post[:topic_id] && post[:post_number] ? post_url(post) : nil
        when Enums::EmbedOwner::USER
          username = @maps.user(owner_id)&.fetch(:username, nil)
          username ? "#{@maps.base_url}/u/#{username}" : nil
        end
      end
    end
  end
end
