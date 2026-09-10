# frozen_string_literal: true

module Migrations
  module Importer
    # Loads a batch's embed rows and resolves source names and coordinates to
    # IntermediateDB original ids. Rendering is deliberately separate: this is
    # the only component in placeholder substitution that queries the database.
    class PlaceholderLinkages
      # SQLite builds may accept more variables, but 999 is the historical
      # guaranteed ceiling. Keeping the limit here makes every dynamic IN query
      # safe independently of the caller's owner batch size.
      DEFAULT_BIND_LIMIT = 999

      TABLES = {
        quote: "embed_quotes",
        link: "embed_links",
        mention: "embed_mentions",
        hashtag: "embed_hashtags",
        emoji: "embed_emojis",
        poll: "embed_polls",
        event: "embed_events",
        upload: "embed_uploads",
      }.freeze
      private_constant :TABLES

      Enums = Migrations::Database::IntermediateDB::Enums
      private_constant :Enums

      def initialize(intermediate_db, bind_limit: DEFAULT_BIND_LIMIT)
        raise ArgumentError, "bind_limit must be at least 2" if bind_limit < 2

        @intermediate_db = intermediate_db
        @bind_limit = bind_limit
        @names = NameResolver.new(intermediate_db)
      end

      # Returns linkage rows grouped by owner id after filling every source id
      # that can be derived from names or coordinates.
      def load_and_resolve(owner_ids, owner_type:)
        linkages = load_linkages(owner_ids.uniq, owner_type:)
        resolve_linkage_ids(linkages)
        linkages
      end

      private

      def load_linkages(owner_ids, owner_type:)
        buckets = {}
        return buckets if owner_ids.empty?

        # One bind is reserved for owner_type.
        owner_ids.each_slice(@bind_limit - 1) do |slice|
          bind_params = (["?"] * slice.size).join(", ")

          TABLES.each do |kind, table|
            sql = "SELECT * FROM #{table} WHERE owner_type = ? AND owner_id IN (#{bind_params})"
            @intermediate_db.query(sql, owner_type, *slice) do |row|
              (buckets[row[:owner_id]] ||= []) << [kind, row]
            end
          end
        end

        buckets
      end

      def resolve_linkage_ids(linkages)
        rows_by_kind = Hash.new { |hash, kind| hash[kind] = [] }
        linkages.each_value { |pairs| pairs.each { |kind, row| rows_by_kind[kind] << row } }

        fill_post_ids(
          rows_by_kind[:quote],
          id: :quoted_post_id,
          topic: :quoted_topic_id,
          number: :quoted_post_number,
        )
        resolve_quoted_usernames(rows_by_kind[:quote])
        resolve_mention_names(rows_by_kind[:mention])
        resolve_hashtags(rows_by_kind[:hashtag])
        resolve_links(rows_by_kind[:link])
      end

      def fill_post_ids(rows, id:, topic:, number:)
        pending = rows.select { |row| row[id].nil? && row[topic] && row[number] }
        return if pending.empty?

        post_ids = post_ids_for_coordinates(pending.map { |row| [row[topic], row[number]] })
        pending.each { |row| row[id] = post_ids[[row[topic], row[number]]] }
      end

      def post_ids_for_coordinates(coordinates)
        post_ids = {}

        coordinates
          .uniq
          .each_slice(@bind_limit / 2) do |slice|
            values = (["(?, ?)"] * slice.size).join(", ")
            sql = <<~SQL
            SELECT original_id, topic_id, post_number
            FROM posts
            WHERE (topic_id, post_number) IN (VALUES #{values})
          SQL

            @intermediate_db.query(sql, *slice.flatten) do |row|
              post_ids[[row[:topic_id], row[:post_number]]] = row[:original_id]
            end
          end

        post_ids
      end

      def resolve_links(link_rows)
        fill_post_ids(
          link_rows,
          id: :target_id,
          topic: :target_topic_id,
          number: :target_post_number,
        )
        resolve_link_names(link_rows)
        resolve_topic_slugs(link_rows)
        resolve_link_tag_paths(link_rows)
      end

      def resolve_topic_slugs(link_rows)
        pending =
          link_rows.select do |row|
            row[:target_type] == Enums::LinkTarget::TOPIC && row[:target_id].nil? &&
              row[:target_name].present?
          end
        return if pending.empty?

        topic_ids = topic_ids_for_slugs(pending.map { |row| row[:target_name] })
        pending.each { |row| row[:target_id] = topic_ids[row[:target_name]] }
      end

      def topic_ids_for_slugs(slugs)
        topic_ids = {}

        slugs
          .uniq
          .each_slice(@bind_limit) do |slice|
            placeholders = (["?"] * slice.size).join(", ")
            sql = <<~SQL
            SELECT slug, MIN(original_id) AS original_id
            FROM topics
            WHERE slug IN (#{placeholders})
            GROUP BY slug
            HAVING COUNT(*) = 1
          SQL

            @intermediate_db.query(sql, *slice) { |row| topic_ids[row[:slug]] = row[:original_id] }
          end

        topic_ids
      end

      def resolve_link_tag_paths(link_rows)
        link_rows.each do |row|
          next unless multi_tag_link?(row)

          ids = tag_path_tags(row).map { |name| @names.tag_id(name) }
          row[:resolved_tag_ids] = ids.any? && ids.all? ? ids : nil
        end
      end

      def multi_tag_link?(row)
        row[:target_type] == Enums::LinkTarget::CATEGORY_TAG ||
          row[:target_type] == Enums::LinkTarget::TAG_INTERSECTION
      end

      TAG_SUBCATEGORY_FILTERS = %w[none all]
      private_constant :TAG_SUBCATEGORY_FILTERS

      def tag_path_filter(row)
        return nil unless row[:target_type] == Enums::LinkTarget::CATEGORY_TAG

        segments = row[:target_tag_path].to_s.split("/")
        return nil unless segments.size > 1

        TAG_SUBCATEGORY_FILTERS.include?(segments.first) ? segments.first : nil
      end

      def tag_path_tags(row)
        segments = row[:target_tag_path].to_s.split("/")
        segments.shift if tag_path_filter(row)
        segments
      end

      def resolve_link_names(link_rows)
        link_rows.each do |row|
          next if row[:target_id] || row[:target_name].blank?

          row[:target_id] = lookup_target_id(row[:target_type], row[:target_name])
        end
      end

      def lookup_target_id(target_type, name)
        case target_type
        when Enums::LinkTarget::USER
          @names.user_id(name)
        when Enums::LinkTarget::GROUP
          @names.group_id(name)
        when Enums::LinkTarget::TAG
          @names.tag_id(name)
        when Enums::LinkTarget::CATEGORY, Enums::LinkTarget::CATEGORY_TAG
          @names.category_id(name)
        end
      end

      def resolve_quoted_usernames(quote_rows)
        quote_rows.each do |row|
          next if row[:quoted_user_id] || row[:quoted_username].blank?

          row[:quoted_user_id] = @names.user_id(row[:quoted_username])
        end
      end

      def resolve_mention_names(mention_rows)
        mention_rows.each do |row|
          next if row[:target_id] || row[:name].blank?

          case row[:mention_type]
          when Enums::MentionType::GROUP
            row[:target_id] = @names.group_id(row[:name])
          when Enums::MentionType::USER, nil
            row[:target_id] = @names.user_id(row[:name])
          end
        end
      end

      def resolve_hashtags(hashtag_rows)
        hashtag_rows.each do |row|
          next if row[:target_id] || row[:name].blank?

          resolved =
            case row[:hashtag_type]
            when Enums::HashtagType::CATEGORY
              @names.category_id(row[:name])&.then { |id| [id, Enums::HashtagType::CATEGORY] }
            when Enums::HashtagType::TAG
              @names.tag_id(row[:name])&.then { |id| [id, Enums::HashtagType::TAG] }
            else
              resolve_untyped_hashtag(row[:name])
            end
          next unless resolved

          row[:target_id], row[:hashtag_type] = resolved
        end
      end

      def resolve_untyped_hashtag(name)
        if (id = @names.category_id(name))
          [id, Enums::HashtagType::CATEGORY]
        elsif (id = @names.tag_id(name))
          [id, Enums::HashtagType::TAG]
        end
      end
    end
  end
end
