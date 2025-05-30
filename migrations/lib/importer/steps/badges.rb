# frozen_string_literal: true

module Migrations::Importer::Steps
  class Badges < ::Migrations::Importer::CopyStep
    DEFAULT_ICON = "certificate"
    DUPLICATE_SUFFIX = "_1"

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

    store_mapped_ids true

    total_rows_query <<~SQL, MappingType::BADGES
      SELECT COUNT(*)
      FROM badges b
           LEFT JOIN mapped.ids mi ON b.original_id = mi.original_id AND mi.type = ?
      WHERE mi.original_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::BADGES
      SELECT b.*
      FROM badges b
           LEFT JOIN mapped.ids mi ON b.original_id = mi.original_id AND mi.type = ?
      WHERE mi.original_id IS NULL
      GROUP BY b.original_id
      ORDER BY b.ROWID
    SQL

    private

    def transform_row(row)
      if row[:existing_id].present?
        row[:id] = if row[:existing_id].match?(/\A\d+\z/)
          id = row[:existing_id].to_i
          id if @existing_ids.include?(id)
        else
          @ids_by_name[row[:existing_id]]
        end

        return nil if row[:id].present?
      end

      badge_name = row[:name].dup
      row[:name] = @existing_names.add?(badge_name) ? badge_name : deduplicate_name(badge_name)

      row[:allow_title] ||= false
      row[:multiple_grant] ||= false
      row[:show_posts] ||= false
      row[:show_in_post_header] ||= false
      row[:target_posts] ||= false
      row[:auto_revoke] = true if row[:auto_revoke].nil?
      row[:enabled] = true if row[:enabled].nil?
      row[:listable] = true if row[:listable].nil?

      row[:icon] = DEFAULT_ICON if row[:icon].blank?
      row[:trigger] = Badge::Trigger::None unless valid_trigger?(row[:trigger])

      # TODO: Update these if/when we add import steps for badge groupings and badge types
      #       Current implementation expects the converter to set final values
      row[:badge_grouping_id] = ensure_related_id(
        row[:badge_grouping_id],
        @existing_badge_grouping_ids,
        BadgeGrouping::Other,
      )
      row[:badge_type_id] = ensure_related_id(
        row[:badge_type_id],
        @existing_badge_type_ids,
        BadgeType::Silver,
      )

      # TODO: Probably validate the imported query, maybe in some other step
      row[:query] = nil if !SiteSetting.enable_badge_sql? && row[:query].present?

      # TODO: Resolve and include image_upload_id once have an uploads step

      super
    end

    def deduplicate_name(name)
      new_name = name + DUPLICATE_SUFFIX
      new_name.next! until @existing_names.add?(new_name)

      new_name
    end

    def ensure_related_id(value, allowed_set, default_value)
      allowed_set.include?(value) ? value : default_value
    end

    def valid_trigger?(trigger)
      return false if trigger.blank?

      Badge::Trigger.is_none?(trigger) || Badge::Trigger.uses_user_ids?(trigger) ||
        Badge::Trigger.uses_post_ids?(trigger)
    end
  end
end
