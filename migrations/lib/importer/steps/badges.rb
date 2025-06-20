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
      ORDER BY b.ROWID
    SQL

    private

    def transform_row(row)
      if (existing_id = row[:existing_id])
        row[:id] = if existing_id.match?(/\A\d+\z/)
          id = existing_id.to_i
          @existing_ids.include?(id) ? id : nil
        else
          @ids_by_name[existing_id]
        end

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
      row[:badge_grouping_id] = ensure_valid_badge_grouping_id(row)
      row[:badge_type_id] = ensure_valid_badge_type_id(row)
      row[:query] = ensure_valid_query(row)

      # TODO: Resolve and include image_upload_id once have an uploads step

      super
    end

    def ensure_unique_name(name)
      return name if @existing_names.add?(name)

      name = name.dup
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
        # TODO(selase): Adopt importer framework warning logging implementation once available
        Rails.logger.warn "#{row[:name]}: Invalid badge trigger '#{invalid}', using default '#{default}'"
      end
    end

    def ensure_valid_badge_grouping_id(row)
      ensure_valid_value(
        value: row[:badge_grouping_id],
        allowed_set: @existing_badge_grouping_ids,
        default_value: BadgeGrouping::Other,
      )
    end

    def ensure_valid_badge_type_id(row)
      ensure_valid_value(
        value: row[:badge_type_id],
        allowed_set: @existing_badge_type_ids,
        default_value: BadgeType::Silver,
      )
    end

    def ensure_valid_value(value:, allowed_set:, default_value:)
      return value if allowed_set.include?(value)

      yield(value, default_value) if block_given?
      default_value
    end

    def ensure_valid_query(row)
      # TODO(selase):
      #  Adopt importer framework warning logging  implementation once available
      query = row[:query].presence

      return nil unless query

      name = row[:name]

      unless SiteSetting.enable_badge_sql?
        Rails.logger.warn "#{name}: Badge SQL is not enabled"
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
        Rails.logger.warn "#{name}: Invalid badge query: #{e.message}"
        nil
      end
    end
  end
end
