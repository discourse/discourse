# frozen_string_literal: true

module Migrations::Importer::Steps
  class Badges < ::Migrations::Importer::CopyStep
    DEFAULT_ICON = "certificate"
    DUPLICATE_SUFFIX = "_1"
    VALID_TRIGGERS =
      Badge::Trigger
        .constants(false)
        .filter_map { Badge::Trigger.const_get(_1) unless _1 == :DeprecatedPostProcessed }
        .to_set
        .freeze

    depends_on :uploads
    store_mapped_ids true

    requires_mapping :ids_by_name, "SELECT name, id FROM badges"
    requires_set :existing_ids, "SELECT id FROM badges"
    requires_set :existing_names, "SELECT name FROM badges"
    requires_set :existing_badge_grouping_ids, "SELECT id FROM badge_groupings"
    requires_set :existing_badge_type_ids, "SELECT id FROM badge_types"

    column_names %i[
                   id
                   name
                   description
                   badge_type_id
                   created_at
                   updated_at
                   allow_title
                   multiple_grant
                   icon
                   listable
                   target_posts
                   query
                   enabled
                   auto_revoke
                   badge_grouping_id
                   trigger
                   show_posts
                   long_description
                   image_upload_id
                   show_in_post_header
                 ]

    total_rows_query <<~SQL, MappingType::BADGES
      SELECT COUNT(*)
      FROM badges b
           LEFT JOIN mapped.ids mb ON b.original_id = mb.original_id AND mb.type = ?
      WHERE mb.original_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::BADGES, MappingType::UPLOADS
      SELECT b.*,
             mup.discourse_id AS resolved_image_upload_id
      FROM badges b
           LEFT JOIN mapped.ids mb ON b.original_id = mb.original_id AND mb.type = ?1
           LEFT JOIN mapped.ids mup ON b.image_upload_id = mup.original_id AND mup.type = ?2
      WHERE mb.original_id IS NULL
      ORDER BY b.ROWID
    SQL

    private

    def transform_row(row)
      if (existing_id = row[:existing_id])
        row[:id] = resolve_existing_id(existing_id)

        return nil if row[:id]
      end

      row[:name] = ensure_unique_name(row[:name])

      row[:allow_title] ||= false
      row[:multiple_grant] ||= false
      row[:show_posts] ||= false
      row[:show_in_post_header] ||= false
      row[:target_posts] ||= false
      row[:auto_revoke] = true if row[:auto_revoke].nil?
      row[:enabled] = true if row[:enabled].nil?
      row[:listable] = true if row[:listable].nil?

      row[:icon] = DEFAULT_ICON if row[:icon].blank?
      row[:trigger] = ensure_valid_trigger(row)
      row[:badge_grouping_id] = ensure_valid_value(
        value: row[:badge_grouping_id],
        allowed_set: @existing_badge_grouping_ids,
        default_value: BadgeGrouping::Other,
      )
      row[:badge_type_id] = ensure_valid_value(
        value: row[:badge_type_id],
        allowed_set: @existing_badge_type_ids,
        default_value: BadgeType::Silver,
      )
      row[:query] = ensure_valid_query(row)

      row[:image_upload_id] = row[:resolved_image_upload_id]

      super
    end

    def resolve_existing_id(existing_id)
      if existing_id.match?(/\A\d+\z/)
        id = existing_id.to_i
        @existing_ids.include?(id) ? id : nil
      else
        @ids_by_name[existing_id]
      end
    end

    def ensure_unique_name(name)
      return name if @existing_names.add?(name)

      new_name = name + DUPLICATE_SUFFIX
      new_name.next! until @existing_names.add?(new_name)

      new_name
    end

    def ensure_valid_trigger(row)
      ensure_valid_value(
        value: row[:trigger],
        allowed_set: VALID_TRIGGERS,
        default_value: Badge::Trigger::None,
      ) do |invalid, default|
        # TODO(selase): Adopt importer framework warning implementation once available
        puts "    #{row[:name]}: Invalid badge trigger '#{invalid}', using default '#{default}'"
      end
    end

    def ensure_valid_query(row)
      query = row[:query].presence

      return nil unless query

      name = row[:name]

      unless SiteSetting.enable_badge_sql?
        # TODO(selase):
        #  Adopt importer framework warning implementation once available
        #  No need to log this for every badge, just once will suffice. Maybe some
        #  top-level prerequisite check with warnings
        puts "    #{name}: Badge SQL is not enabled"
        return nil
      end

      begin
        BadgeGranter.contract_checks!(
          query,
          target_posts: row[:target_posts],
          trigger: row[:trigger],
        )
        query
      rescue StandardError => e
        # TODO(selase): Adopt importer framework warning implementation once available
        puts "    #{name}: Invalid badge query: #{e.message}"
        nil
      end
    end
  end
end
