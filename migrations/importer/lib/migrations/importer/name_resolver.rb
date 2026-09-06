# frozen_string_literal: true

module Migrations
  module Importer
    # Answers "what source `original_id` does this name point at?" for the four
    # kinds of source name a linkage row can carry: a username, a group name, a
    # category (a bare slug or a `parent:child` path), and a tag name.
    #
    # Every lookup family is built lazily, with one query, the first time a batch
    # needs it. Names come in raw and are normalized inside; callers never
    # normalize. Normalization matches the converter side (`NameNormalizer`), so
    # the two sides can't disagree on what counts as the same name.
    class NameResolver
      def initialize(intermediate_db)
        @intermediate_db = intermediate_db
      end

      def user_id(name)
        user_id_by_name[normalize(name)]
      end

      def group_id(name)
        group_id_by_name[normalize(name)]
      end

      # A `parent:child` name resolves against the full slug path; a bare slug
      # resolves against the leaf, preferring a top-level category.
      def category_id(name)
        key = normalize(name)
        key.include?(":") ? category_maps[:by_path][key] : category_maps[:by_slug][key]
      end

      def tag_id(name)
        tag_id_by_name[normalize(name)]
      end

      private

      # The source's name -> original_id maps. They can be large (a full-site users
      # map is one entry per user), so each is built at most once per resolver and
      # only when a batch actually needs it.
      def user_id_by_name
        @user_id_by_name ||= build_name_map("SELECT original_id, username AS name FROM users")
      end

      def group_id_by_name
        @group_id_by_name ||= build_name_map('SELECT original_id, name FROM "groups"')
      end

      def build_name_map(sql)
        map = {}
        @intermediate_db.query(sql) { |row| map[normalize(row[:name])] = row[:original_id] }
        map
      end

      # Two lazily-built category lookups, keyed by normalized slug:
      #   * `by_path` — the full slug path, root-first `:`-joined
      #     (`"slug"`, `"parent:child"`, `"a:b:c"`, …) => original_id.
      #   * `by_slug` — the leaf slug => original_id, top-level category preferred.
      def category_maps
        @category_maps ||= build_category_maps
      end

      def build_category_maps
        slug_of = {}
        parent_of = {}
        order = []

        # SQLite sorts NULLs first, so top-level categories come before children;
        # with `||=` below that gives a bare slug shared by both a top-level and a
        # child category to the top-level one, the way Discourse resolves it.
        sql = <<~SQL
          SELECT original_id, slug, parent_category_id
          FROM categories
          ORDER BY parent_category_id, original_id
        SQL
        @intermediate_db.query(sql) do |row|
          id = row[:original_id]
          slug_of[id] = normalize(row[:slug])
          parent_of[id] = row[:parent_category_id]
          order << id
        end

        by_path = {}
        by_slug = {}
        order.each do |id|
          slug = slug_of[id]
          by_path[category_path(id, slug_of, parent_of)] ||= id
          by_slug[slug] ||= id
        end

        { by_path:, by_slug: }
      end

      # The full slug path for a category, root-first, every ancestor slug joined
      # with ":". A source with deeper nesting (max_category_nesting = 3) records
      # id-less `/c/a/b/c` links as "a:b:c", so the path must carry every level,
      # not just the immediate parent. A two-level category still comes out as
      # "parent:child", exactly as before.
      #
      # The visited check guards a corrupt source whose parent chain loops. On
      # hitting the guard we keep the path built so far rather than raising: one
      # bad chain should degrade, not crash the whole import.
      def category_path(id, slug_of, parent_of)
        slugs = [slug_of[id]]
        seen = { id => true }
        parent_id = parent_of[id]
        while parent_id && !seen[parent_id]
          seen[parent_id] = true
          slugs.unshift(slug_of[parent_id])
          parent_id = parent_of[parent_id]
        end
        slugs.join(":")
      end

      # Tag name => canonical original_id, with synonyms folded onto their target so
      # `#oldname` and `#newname` resolve to the same tag.
      def tag_id_by_name
        @tag_id_by_name ||= build_tag_id_map
      end

      def build_tag_id_map
        canonical = {}
        @intermediate_db.query("SELECT synonym_tag_id, target_tag_id FROM tag_synonyms") do |row|
          canonical[row[:synonym_tag_id]] = row[:target_tag_id]
        end

        map = {}
        @intermediate_db.query("SELECT original_id, name FROM tags") do |row|
          map[normalize(row[:name])] = canonical[row[:original_id]] || row[:original_id]
        end
        map
      end

      def normalize(name)
        Migrations::NameNormalizer.normalize(name)
      end
    end
  end
end
