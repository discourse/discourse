# frozen_string_literal: true

module Migrations::Importer::Steps
  class Topics < ::Migrations::Importer::CopyStep
    ARCHETYPES = Archetype.list.map(&:id).to_set.freeze
    DEFAULT_ARCHETYPE = Archetype.default
    SUBTYPES = TopicSubtype.instance_variable_get(:@subtypes).keys.to_set.freeze
    VISIBILITY_REASONS = Topic.visibility_reasons.values.to_set.freeze
    DEFAULT_VIEWS = 0
    EXTERNAL_ID_FORMAT = /\A[\w-]+\z/
    UNCATEGORIZED_ID = SiteSetting.uncategorized_category_id
    MAX_TOPIC_TITLE_LENGTH = SiteSetting.max_topic_title_length

    depends_on :categories, :users, :uploads
    store_mapped_ids true

    requires_set :existing_external_ids, "SELECT LOWER(external_id) FROM topics"

    column_names %i[
                   id
                   archetype
                   archived
                   bannered_until
                   bumped_at
                   category_id
                   closed
                   created_at
                   deleted_at
                   deleted_by_id
                   external_id
                   featured_link
                   last_post_user_id
                   pinned_at
                   pinned_globally
                   pinned_until
                   subtype
                   slug
                   title
                   updated_at
                   user_id
                   views
                   visibility_reason_id
                   visible
                 ]

    total_rows_query <<~SQL, MappingType::TOPICS
      SELECT COUNT(*)
      FROM topics
           LEFT JOIN mapped.ids mapped_topic
             ON topics.original_id = mapped_topic.original_id  AND mapped_topic.type = ?1
      WHERE mapped_topic.original_id IS NULL
    SQL

    rows_query <<~SQL, MappingType::TOPICS, MappingType::CATEGORIES, MappingType::USERS
      SELECT topics.*,
              mapped_category.discourse_id        AS discourse_category_id,
              mapped_user.discourse_id            AS discourse_user_id,
              mapped_deleted_by_user.discourse_id AS discourse_deleted_by_user_id
      FROM topics
           LEFT JOIN mapped.ids mapped_topic
             ON topics.original_id = mapped_topic.original_id  AND mapped_topic.type = ?1
           LEFT JOIN mapped.ids mapped_category
             ON topics.category_id = mapped_category.original_id  AND mapped_category.type = ?2
           LEFT JOIN mapped.ids mapped_user
             ON topics.user_id = mapped_user.original_id  AND mapped_user.type = ?3
           LEFT JOIN mapped.ids mapped_deleted_by_user
             ON topics.deleted_by_id = mapped_deleted_by_user.original_id  AND mapped_deleted_by_user.type = ?3
      WHERE mapped_topic.original_id IS NULL
    SQL

    private

    def transform_row(row)
      return nil if row[:archetype] != Archetype.private_message && row[:discourse_category_id].nil?

      if (external_id = row[:external_id])
        return nil unless process_external_id(external_id)
      end

      row[:archived] ||= false
      row[:closed] ||= false
      row[:visible] = true if row[:visible].nil?

      row[:views] ||= DEFAULT_VIEWS

      row[:category_id] = row[:discourse_category_id] ||
        (UNCATEGORIZED_ID if row[:archetype] != Archetype.private_message)
      row[:deleted_by_id] = row[:discourse_deleted_by_user_id]
      row[:user_id] = row[:discourse_user_id] || SYSTEM_USER_ID

      row[:title] = row[:title][0, MAX_TOPIC_TITLE_LENGTH].scrub.strip
      row[:last_post_user_id] ||= row[:user_id]
      row[:slug] = Slug.for(row[:title])
      row[:bumped_at] = row[:created_at]

      row[:archetype] = ensure_valid_value(
        value: row[:archetype],
        allowed_set: ARCHETYPES,
        default_value: DEFAULT_ARCHETYPE,
      ) do |_, default_value|
        puts "   #{row[:id]}: Topic archetype is invalid, defaulting to #{default_value}"
      end
      row[:subtype] = ensure_valid_value(
        value: row[:subtype],
        allowed_set: SUBTYPES,
        default_value: nil,
      ) if row[:subtype]
      row[:visibility_reason_id] = ensure_valid_value(
        value: row[:visibility_reason_id],
        allowed_set: VISIBILITY_REASONS,
        default_value: nil,
      ) if row[:visibility_reason_id]

      super
    end

    def process_external_id(external_id)
      return nil if external_id.blank?

      external_id = external_id.strip

      if external_id.length > Topic::EXTERNAL_ID_MAX_LENGTH ||
           !external_id.match?(EXTERNAL_ID_FORMAT)
        puts "    Invalid format or length for external_id '#{external_id}'"

        return false
      end

      unless @existing_external_ids.add?(external_id.downcase)
        puts "    Duplicate external_id '#{external_id}'"

        return false
      end

      true
    end
  end
end
