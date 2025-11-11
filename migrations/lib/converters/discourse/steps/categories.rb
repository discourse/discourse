# frozen_string_literal: true

module Migrations::Converters::Discourse
  class Categories < ::Migrations::Converters::Base::ProgressStep
    SEEDED_CATEGORY_SETTINGS = %w[
      uncategorized_category_id
      meta_category_id
      staff_category_id
      general_category_id
    ].freeze

    attr_accessor :source_db

    def execute
      super

      @background_upload_creator = UploadCreator.new(column_prefix: "background")
      @background_dark_upload_creator = UploadCreator.new(column_prefix: "background_dark")
      @logo_upload_creator = UploadCreator.new(column_prefix: "logo")
      @logo_dark_upload_creator = UploadCreator.new(column_prefix: "logo_dark")
    end

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM categories
      SQL
    end

    def items
      @source_db.query(
        <<~SQL,
        SELECT c.*,
               ss.name AS existing_id,
               bg.url                      AS background_url,
               bg.original_filename        AS background_filename,
               bg.origin                   AS background_origin,
               bg.user_id                  AS background_user_id,
               bg_dark.url                 AS background_dark_url,
               bg_dark.original_filename   AS background_dark_filename,
               bg_dark.origin              AS background_dark_origin,
               bg_dark.user_id             AS background_dark_user_id,
               logo.url                    AS logo_url,
               logo.original_filename      AS logo_filename,
               logo.origin                 AS logo_origin,
               logo.user_id                AS logo_user_id,
               logo_dark.url               AS logo_dark_url,
               logo_dark.original_filename AS logo_dark_filename,
               logo_dark.origin            AS logo_dark_origin,
               logo_dark.user_id           AS logo_dark_user_id
        FROM categories c
             LEFT JOIN site_settings ss ON $1
                                        AND c.id    = ss.value::int
                                        AND ss.name = ANY($2::text[])
             LEFT JOIN uploads bg ON c.uploaded_background_id           = bg.id
             LEFT JOIN uploads bg_dark ON c.uploaded_background_dark_id = bg_dark.id
             LEFT JOIN uploads logo ON c.uploaded_logo_id               = logo.id
             LEFT JOIN uploads logo_dark ON c.uploaded_logo_dark_id     = logo_dark.id
        ORDER BY c.id
      SQL
        !!settings.dig(:categories, :map_seeded_categories),
        @source_db.encode_array(SEEDED_CATEGORY_SETTINGS),
      )
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
        uploaded_background_dark_id: @background_dark_upload_creator.create_for(item),
        uploaded_background_id: @background_upload_creator.create_for(item),
        uploaded_logo_dark_id: @logo_dark_upload_creator.create_for(item),
        uploaded_logo_id: @logo_upload_creator.create_for(item),
        user_id: item[:user_id],
      )
    end
  end
end
