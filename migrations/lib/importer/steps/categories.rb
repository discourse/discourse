# frozen_string_literal: true

module Migrations::Importer::Steps
  class Categories < ::Migrations::Importer::CopyStep
    DEFAULT_COLOR = "0088CC"
    DEFAULT_LIST_FILTER = "all"
    DEFAULT_TOP_PERIOD = "all"
    DEFAULT_MINIMUM_REQUIRED_TAGS = 0
    DEFAULT_STYLE_TYPE = "square"
    DEFAULT_SUBCATEGORY_LIST_STYLE = "rows_with_featured_topics"
    DEFAULT_TEXT_COLOR = "FFFFFF"
    MAX_NAME_LENGTH = 50

    depends_on :users, :uploads
    store_mapped_ids true

    requires_mapping :ids_by_name, "SELECT name, id FROM categories"
    requires_set :existing_ids, "SELECT id FROM categories"
    requires_set :existing_category_names, <<~SQL
      SELECT COALESCE(parent_category_id::text, '') || '-' || LOWER(name) FROM categories
    SQL
    requires_set :existing_slugs, <<~SQL
      SELECT
        COALESCE(parent_category_id::text, '') || ':' || LOWER(slug)
      FROM categories
      WHERE slug <> ''
    SQL

    column_names %i[
                   id
                   all_topics_wiki
                   allow_badges
                   allow_global_tags
                   allow_unlimited_owner_edits_on_first_post
                   auto_close_based_on_last_post
                   auto_close_hours
                   color
                   created_at
                   updated_at
                   default_list_filter
                   default_slow_mode_seconds
                   default_top_period
                   default_view
                   description
                   email_in
                   email_in_allow_strangers
                   emoji
                   icon
                   mailinglist_mirror
                   minimum_required_tags
                   name
                   name_lower
                   navigate_to_first_post_after_read
                   num_featured_topics
                   parent_category_id
                   position
                   read_only_banner
                   read_restricted
                   show_subcategory_list
                   slug
                   sort_ascending
                   sort_order
                   style_type
                   subcategory_list_style
                   text_color
                   topic_featured_link_allowed
                   topic_template
                   uploaded_background_dark_id
                   uploaded_background_id
                   uploaded_logo_dark_id
                   uploaded_logo_id
                   user_id
                 ]

    total_rows_query <<~SQL, MappingType::CATEGORIES
      SELECT COUNT(*)
      FROM categories c
          LEFT JOIN mapped.ids mapped_category
            ON c.original_id = mapped_category.original_id AND mapped_category.type = ?
      WHERE mapped_category.original_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::CATEGORIES, MappingType::USERS, MappingType::UPLOADS
      WITH
          RECURSIVE
          tree AS (
                    SELECT c.*, 0 AS level
                      FROM categories c
                    WHERE c.parent_category_id IS NULL
                    UNION ALL
                    SELECT c.*, tree.level + 1 AS level
                      FROM categories c,
                          tree
                    WHERE c.parent_category_id = tree.original_id
                  )
      SELECT t.*,
            COALESCE(t.position,
                      ROW_NUMBER() OVER (
                        PARTITION BY parent_category_id
                        ORDER BY parent_category_id NULLS FIRST, name
                        )
                    ) AS position,
            mapped_user.discourse_id      AS mapped_user_id,
            mapped_bg.discourse_id        AS mapped_uploaded_background_id,
            mapped_bg_dark.discourse_id   AS mapped_uploaded_background_dark_id,
            mapped_logo.discourse_id      AS mapped_uploaded_logo_id,
            mapped_logo_dark.discourse_id AS mapped_uploaded_logo_dark_id
      FROM tree t
           LEFT JOIN mapped.ids mapped_category
             ON t.original_id = mapped_category.original_id AND mapped_category.type = ?1
           LEFT JOIN mapped.ids mapped_user
              ON t.user_id = mapped_user.original_id AND mapped_user.type = ?2
           LEFT JOIN mapped.ids mapped_bg
             ON t.uploaded_background_id = mapped_bg.original_id AND mapped_bg.type = ?3
           LEFT JOIN mapped.ids mapped_bg_dark
             ON t.uploaded_background_dark_id = mapped_bg_dark.original_id AND mapped_bg_dark.type = ?3
           LEFT JOIN mapped.ids mapped_logo
             ON t.uploaded_logo_id = mapped_logo.original_id AND mapped_logo.type = ?3
           LEFT JOIN mapped.ids mapped_logo_dark
             ON t.uploaded_logo_dark_id = mapped_logo_dark.original_id AND mapped_logo_dark.type = ?3
      WHERE mapped_category.original_id IS NULL
      ORDER BY t.level, position, t.original_id
    SQL

    def execute
      @highest_position = Category.unscoped.maximum(:position) || 0
      @mapped_category_ids = @intermediate_db.query_array(<<~SQL, MappingType::CATEGORIES).to_h
        SELECT original_id, discourse_id FROM  mapped.ids WHERE type = ?
      SQL

      super
    end

    private

    def transform_row(row)
      if (existing_id = row[:existing_id])
        row[:id] = resolve_existing_id(existing_id)

        return nil if row[:id].present?
      end

      row[:all_topics_wiki] ||= false
      row[:allow_global_tags] ||= false
      row[:allow_unlimited_owner_edits_on_first_post] ||= false
      row[:auto_close_based_on_last_post] ||= false
      row[:email_in_allow_strangers] ||= false
      row[:mailinglist_mirror] ||= false
      row[:navigate_to_first_post_after_read] ||= false
      row[:read_restricted] ||= false
      row[:show_subcategory_list] ||= false

      row[:allow_badges] = true if row[:allow_badges].nil?
      row[:topic_featured_link_allowed] = true if row[:topic_featured_link_allowed].nil?

      row[:color] ||= DEFAULT_COLOR
      row[:description] = (row[:description] || "").scrub.strip.presence
      row[:default_list_filter] ||= DEFAULT_LIST_FILTER
      row[:default_top_period] ||= DEFAULT_TOP_PERIOD
      row[:minimum_required_tags] ||= DEFAULT_MINIMUM_REQUIRED_TAGS
      row[:parent_category_id] = @mapped_category_ids[row[:parent_category_id]]
      row[:name], row[:name_lower] = ensure_unique_name(row[:name], row[:parent_category_id])
      row[:slug] = ensure_unique_slug(row[:slug], row[:parent_category_id], row[:name_lower])

      row[:style_type] ||= DEFAULT_STYLE_TYPE
      row[:subcategory_list_style] ||= DEFAULT_SUBCATEGORY_LIST_STYLE
      row[:text_color] ||= DEFAULT_TEXT_COLOR
      row[:user_id] = row[:mapped_user_id] || Discourse::SYSTEM_USER_ID
      row[:uploaded_background_dark_id] = row[:mapped_uploaded_background_dark_id]
      row[:uploaded_background_id] = row[:mapped_uploaded_background_id]
      row[:uploaded_logo_dark_id] = row[:mapped_uploaded_logo_dark_id]
      row[:uploaded_logo_id] = row[:mapped_uploaded_logo_id]

      if row[:position]
        @highest_position = row[:position] if row[:position] > @highest_position
      else
        row[:position] = @highest_position += 1
      end

      super

      # `parent_category_id` is self-referential. In addition to loading existing category IDs
      # at the start of the step, we also need to track mapped IDs created during the step
      @mapped_category_ids[row[:original_id]] = row[:id] unless @mapped_category_ids.key?(
        row[:original_id],
      )

      row
    end

    def resolve_existing_id(existing_id)
      return if existing_id.blank?

      case existing_id
      when /\A\d+\z/
        id = existing_id.to_i
        id if @existing_ids.include?(id)
      when /_id\z/
        begin
          SiteSetting.get(existing_id)
        rescue StandardError => e
          # TODO(selase): Adopt importer framework warning implementation once available
          puts "    #{e.message}"
          nil
        end
      else
        @ids_by_name[existing_id]
      end
    end

    def ensure_unique_name(original_name, parent_id)
      truncated_name = original_name[0...MAX_NAME_LENGTH].scrub.strip
      name_lower = truncated_name.downcase

      if @existing_category_names.add?("#{parent_id}-#{name_lower}")
        return truncated_name, name_lower
      end

      counter = 1
      loop do
        suffix = counter.to_s
        trim_length = MAX_NAME_LENGTH - suffix.length

        candidate_name = "#{truncated_name[0...trim_length]}#{suffix}"
        candidate_name_lower = candidate_name.downcase

        if @existing_category_names.add?("#{parent_id}-#{candidate_name_lower}")
          return candidate_name, candidate_name_lower
        end

        counter += 1
      end
    end

    def ensure_unique_slug(slug, parent_id, name_lower)
      # `name_lower` is already deduplicated,
      # safe to use directly as fallback without deduplication
      return Slug.for(name_lower, "") if slug.blank?

      parent_prefix = "#{parent_id}:"
      slug_lower = slug.downcase

      return slug if @existing_slugs.add?("#{parent_prefix}#{slug_lower}")

      new_slug = "#{slug_lower}-1"
      new_slug.next! until @existing_slugs.add?("#{parent_prefix}#{new_slug}")

      new_slug
    end
  end
end
