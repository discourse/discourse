# frozen_string_literal: true

module Migrations
  module Importer
    # The destination values {PlaceholderResolver} needs while it rewrites a
    # body. Every lookup answers from memory, because the resolver calls them
    # once per token.
    #
    # A map joins two databases: the source id of a record is in the attached
    # SQLite mappings database, the record's own values are in PostgreSQL. Both
    # sides are read once, streamed, and joined here. The destination-keyed hash
    # that the join needs is dropped as soon as the source-keyed map is built, so
    # a map costs one entry per record and nothing else.
    #
    # Posts are the exception: a full site has far too many of them to keep, so
    # only the posts of the current batch are held (see {#prime_posts}).
    class PlaceholderMaps
      # Structs, not hashes: at full-site scale a map has millions of entries,
      # and a Struct instance is a fraction of a Hash. `[]` and `dig` work the
      # same way for the resolver.
      MappedUser = Struct.new(:username, :name)
      MappedPost = Struct.new(:topic_id, :post_number)
      MappedBadge = Struct.new(:id, :slug)
      MappedUpload = Struct.new(:short_url, :url, :markdown)

      # One bind is reserved for the mapping type.
      POST_BIND_LIMIT = PlaceholderLinkages::DEFAULT_BIND_LIMIT - 1
      private_constant :POST_BIND_LIMIT

      POSTS_SQL = <<~SQL
        SELECT post_numbers.original_id,
               mapped_topic.discourse_id AS topic_id,
               post_numbers.post_number
        FROM mapped.post_numbers post_numbers
             JOIN mapped.ids mapped_topic
               ON mapped_topic.original_id = post_numbers.topic_original_id
                  AND mapped_topic.type = ?
        WHERE post_numbers.original_id IN (%s)
      SQL
      private_constant :POSTS_SQL

      def initialize(intermediate_db, discourse_db)
        @intermediate_db = intermediate_db
        @discourse_db = discourse_db
        @posts = {}
      end

      # Replaces the held posts with the ones of the next batch. Ids the batch
      # turns out to need on top of these are fetched one by one and kept until
      # the following batch.
      def prime_posts(original_ids)
        @posts = original_ids.to_h { |id| [id, nil] }
        @posts.merge!(load_posts(original_ids))

        nil
      end

      def post(id)
        return @posts[id] if @posts.key?(id)

        @posts[id] = load_posts([id])[id]
      end

      def user(id)
        users[id]
      end

      def group_name(id)
        group_names[id]
      end

      def topic_id(id)
        topic_ids[id]
      end

      def category_id(id)
        category_ids[id]
      end

      def category_slug_path(id)
        category_slug_paths[id]
      end

      def tag_id(id)
        tag_ids[id]
      end

      def tag_name(id)
        tag_names[id]
      end

      def badge(id)
        badges[id]
      end

      def upload(id)
        uploads[id]
      end

      def upload_markdown(id)
        uploads[id]&.markdown
      end

      # Polls and events have no importer step yet, so their embeds stay
      # unresolved and end up in the run's report.
      def poll_markdown(_id)
        nil
      end

      def event_markdown(_id)
        nil
      end

      def emoji_name(folded_name)
        emoji_names[folded_name]
      end

      def base_url
        @base_url ||= Discourse.base_url
      end

      def here_mention
        @here_mention ||= SiteSetting.here_mention
      end

      private

      def users
        @users ||=
          begin
            sql = "SELECT id, username, name FROM users"
            build_map(sql, MappingType::USERS) do |_id, username, name|
              MappedUser.new(username, name)
            end
          end
      end

      def group_names
        @group_names ||=
          build_map("SELECT id, name FROM groups", MappingType::GROUPS) { |_id, name| name }
      end

      def tag_names
        @tag_names ||=
          build_map("SELECT id, name FROM tags", MappingType::TAGS) { |_id, name| name }
      end

      def badges
        @badges ||=
          build_map("SELECT id, name FROM badges", MappingType::BADGES) do |id, name|
            MappedBadge.new(id, Slug.for(Badge.display_name(name), "-"))
          end
      end

      def topic_ids
        @topic_ids ||= build_id_map(MappingType::TOPICS)
      end

      def category_ids
        @category_ids ||= build_id_map(MappingType::CATEGORIES)
      end

      def tag_ids
        @tag_ids ||= build_id_map(MappingType::TAGS)
      end

      # The path is built from the DESTINATION categories: a merge into an
      # existing site can move a source category under a parent it never had.
      def category_slug_paths
        @category_slug_paths ||=
          begin
            slug_of = {}
            parent_of = {}
            @discourse_db
              .query_array("SELECT id, slug, parent_category_id FROM categories")
              .each do |id, slug, parent_id|
                slug_of[id] = slug
                parent_of[id] = parent_id
              end

            paths = {}
            each_mapping(MappingType::CATEGORIES) do |original_id, discourse_id|
              next unless slug_of.key?(discourse_id)
              paths[original_id] = slug_path(discourse_id, slug_of, parent_of)
            end
            paths
          end
      end

      # Root first, every ancestor slug joined with ":". The visited check keeps
      # a looping parent chain from hanging the import.
      def slug_path(id, slug_of, parent_of)
        slugs = [slug_of[id]]
        seen = { id => true }
        parent_id = parent_of[id]

        while parent_id && !seen[parent_id] && slug_of.key?(parent_id)
          seen[parent_id] = true
          slugs.unshift(slug_of[parent_id])
          parent_id = parent_of[parent_id]
        end

        slugs.join(":")
      end

      # The uploads database holds the attributes of the destination upload, so
      # the short URL and the URL come straight from there. An upload that was
      # skipped because the destination already had its sha1 has no id mapping,
      # but the same sha1 gives the same short URL, so it resolves all the same.
      def uploads
        @uploads ||=
          begin
            map = {}
            sql = "SELECT id, upload, markdown FROM files.uploads WHERE upload IS NOT NULL"

            @intermediate_db.query(sql) do |row|
              attributes = JSON.parse(row[:upload], symbolize_names: true)
              map[row[:id]] = MappedUpload.new(
                short_url(attributes),
                attributes[:url],
                row[:markdown],
              )
            end

            map
          end
      end

      def short_url(attributes)
        sha1 = attributes[:sha1]
        return nil if sha1.blank?

        extension = attributes[:extension]
        basename = Upload.base62_sha1(sha1)
        basename = "#{basename}.#{extension}" if extension.present?
        "upload://#{basename}"
      end

      # There is no custom emoji step yet, so a source name keeps its spelling.
      # Once one exists it has to answer with the name the destination settled
      # on, which may differ after a conflict.
      def emoji_names
        @emoji_names ||=
          begin
            map = {}
            @intermediate_db.query("SELECT name FROM custom_emojis") do |row|
              map[Migrations::NameNormalizer.normalize(row[:name])] = row[:name]
            end
            map
          end
      end

      def build_map(sql, mapping_type)
        values = {}
        @discourse_db.query_array(sql).each { |row| values[row[0]] = yield(*row) }

        map = {}
        each_mapping(mapping_type) do |original_id, discourse_id|
          value = values[discourse_id]
          map[original_id] = value unless value.nil?
        end
        map
      end

      def build_id_map(mapping_type)
        map = {}
        each_mapping(mapping_type) { |original_id, discourse_id| map[original_id] = discourse_id }
        map
      end

      def each_mapping(mapping_type)
        sql = "SELECT original_id, discourse_id FROM mapped.ids WHERE type = ?"
        @intermediate_db.query(sql, mapping_type) do |row|
          yield row[:original_id], row[:discourse_id]
        end
      end

      def load_posts(original_ids)
        posts = {}

        original_ids
          .uniq
          .each_slice(POST_BIND_LIMIT) do |slice|
            sql = format(POSTS_SQL, (["?"] * slice.size).join(", "))

            @intermediate_db.query(sql, MappingType::TOPICS, *slice) do |row|
              posts[row[:original_id]] = MappedPost.new(row[:topic_id], row[:post_number])
            end
          end

        posts
      end
    end
  end
end
