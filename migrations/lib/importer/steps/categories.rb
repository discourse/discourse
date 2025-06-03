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

    requires_mapping :ids_by_name, "SELECT name, id FROM categories"
    requires_set :existing_ids, "SELECT id FROM categories"
    requires_set :category_names, <<~SQL
      SELECT COALESCE(parent_category_id::text, '') || '-' || LOWER(name) FROM categories
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

    store_mapped_ids true

    total_rows_query <<~SQL, MappingType::CATEGORIES
      SELECT COUNT(*)
      FROM categories c
          LEFT JOIN mapped.ids mi ON c.original_id = mi.original_id AND mi.type = ?
      WHERE mi.original_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::CATEGORIES
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
                    ) AS position
      FROM tree t
           LEFT JOIN mapped.ids mi ON t.existing_id = mi.original_id AND mi.type = ?
      WHERE mi.original_id IS NULL
      ORDER BY t.level, position, t.original_id
    SQL

    private

    def transform_row(row)
      if row[:existing_id].present?
        row[:id] = resolve_existing_id(row[:existing_id])

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

      if row[:parent_category_id].present?
        row[:parent_category_id] = resolve_existing_id(row[:parent_category_id])
      end

      name, name_lower = deduplicate_name(row[:name], row[:parent_category_id])

      row[:name] = name
      row[:name_lower] = name_lower
      row[:slug] ||= Slug.for(name_lower, "")

      row[:style_type] ||= DEFAULT_STYLE_TYPE
      row[:subcategory_list_style] ||= DEFAULT_SUBCATEGORY_LIST_STYLE
      row[:text_color] ||= DEFAULT_TEXT_COLOR

      # TODO: Copied as-is from existing importer. Shouldn't `user_id` be resolved here?
      row[:user_id] ||= Discourse::SYSTEM_USER_ID

      # TODO:
      #   1. Explore feasibility of resolving and setting topic_id here
      #   2. User emails are currently not validated, should `email_in` be validated?
      #   3. Resolve and set these once uploads step is available
      #      - `uploaded_background_dark_id`
      #      - `uploaded_background_id`
      #      - `uploaded_logo_dark_id`
      #      - `uploaded_logo_id`

      super
    end

    def resolve_existing_id(existing_id)
      case existing_id
      when /\A\d+\z/
        id = existing_id.to_i
        id if @existing_ids.include?(id)
      when /_id\z/
        SiteSetting.get(existing_id)
      else
        @ids_by_name[existing_id]
      end
    rescue StandardError => e
      puts e.message
      nil
    end

    def deduplicate_name(original_name, parent_id)
      truncated_name = original_name[0...MAX_NAME_LENGTH].scrub.strip
      downcased_name = truncated_name.downcase

      parent_key = parent_id.to_s
      name_key = "#{parent_key}-#{downcased_name}"

      return truncated_name, downcased_name if @category_names.add?(name_key)

      counter = 1
      loop do
        suffix = counter.to_s
        trim_length = MAX_NAME_LENGTH - suffix.length

        candidate_name = "#{truncated_name[0...trim_length]}#{suffix}"
        downcased_candidate_name = candidate_name.downcase
        candidate_name_key = "#{parent_key}-#{downcased_candidate_name}"

        return candidate_name, downcased_candidate_name if @category_names.add?(candidate_name_key)

        counter += 1
      end
    end
  end
end
