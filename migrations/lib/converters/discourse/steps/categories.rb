# frozen_string_literal: true

module Migrations::Converters::Discourse
  class Categories < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM categories
      SQL
    end

    def items
      skip_existing_ids = settings.dig(:categories, :skip_existing_ids) ? "TRUE" : "FALSE"

      @source_db.query <<~SQL
        WITH seeded_categories AS (
                                    SELECT value::int as category_id, name as setting_name
                                    FROM site_settings
                                    WHERE name IN (
                                      'uncategorized_category_id',
                                      'meta_category_id',
                                      'staff_category_id',
                                      'general_category_id'
                                    )
        )
        SELECT c.*,
               CASE WHEN #{skip_existing_ids} THEN NULL ELSE sc.setting_name END AS existing_id
        FROM categories c
             LEFT JOIN seeded_categories sc ON c.id = sc.category_id;
      SQL
    end

    def process_item(item)
      IntermediateDB::Category.create(
        original_id: item[:id],
        about_topic_title: item[:about_topic_title],
        all_topics_wiki: item[:all_topics_wiki],
        allow_badges: item[:allow_badges],
        allow_global_tags: item[:allow_global_tags],
        allow_unlimited_owner_edits_on_first_post: item[:allow_unlimited_owner_edits_on_first_post],
        auto_close_based_on_last_post: item[:auto_close_based_on_last_post],
        auto_close_hours: item[:auto_close_hours],
        color: item[:color],
        created_at: item[:created_at],
        default_list_filter: item[:default_list_filter],
        default_slow_mode_seconds: item[:default_slow_mode_seconds],
        default_top_period: item[:default_top_period],
        default_view: item[:default_view],
        description: item[:description],
        email_in: item[:email_in],
        email_in_allow_strangers: item[:email_in_allow_strangers],
        emoji: item[:emoji],
        existing_id: item[:existing_id],
        icon: item[:icon],
        mailinglist_mirror: item[:mailinglist_mirror],
        minimum_required_tags: item[:minimum_required_tags],
        name: item[:name],
        navigate_to_first_post_after_read: item[:navigate_to_first_post_after_read],
        num_featured_topics: item[:num_featured_topics],
        parent_category_id: item[:parent_category_id],
        position: item[:position],
        read_only_banner: item[:read_only_banner],
        read_restricted: item[:read_restricted],
        reviewable_by_group_id: item[:reviewable_by_group_id],
        search_priority: item[:search_priority],
        show_subcategory_list: item[:show_subcategory_list],
        slug: item[:slug],
        sort_ascending: item[:sort_ascending],
        sort_order: item[:sort_order],
        style_type: item[:style_type],
        subcategory_list_style: item[:subcategory_list_style],
        text_color: item[:text_color],
        topic_featured_link_allowed: item[:topic_featured_link_allowed],
        topic_id: item[:topic_id],
        topic_template: item[:topic_template],
        uploaded_background_dark_id: item[:uploaded_background_dark_id],
        uploaded_background_id: item[:uploaded_background_id],
        uploaded_logo_dark_id: item[:uploaded_logo_dark_id],
        uploaded_logo_id: item[:uploaded_logo_id],
        user_id: item[:user_id],
      )
    end
  end
end
