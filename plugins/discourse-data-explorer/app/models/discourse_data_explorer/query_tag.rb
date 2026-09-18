# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryTag < ActiveRecord::Base
    self.table_name = "data_explorer_tags"

    MAX_TAGS_PER_QUERY = 10
    MAX_NAME_LENGTH = 100

    has_many :query_tag_mappings,
             class_name: "DiscourseDataExplorer::QueryTagMapping",
             dependent: :delete_all

    validates :name,
              presence: true,
              uniqueness: true,
              length: {
                maximum: MAX_NAME_LENGTH,
              },
              format: {
                without: /,/,
              }

    def self.normalize_name(name)
      name.to_s.strip.downcase.gsub(/[[:space:]]+/, " ")
    end

    def self.normalize_all(names)
      Array.wrap(names).map { |name| normalize_name(name) }.reject(&:blank?).uniq
    end

    def self.validate_names(names, errors)
      if names.size > MAX_TAGS_PER_QUERY
        errors.add(
          :base,
          I18n.t("discourse_data_explorer.errors.too_many_tags", max: MAX_TAGS_PER_QUERY),
        )
      end

      if names.any? { |name| name.length > MAX_NAME_LENGTH }
        errors.add(
          :base,
          I18n.t("discourse_data_explorer.errors.tag_too_long", max: MAX_NAME_LENGTH),
        )
      end

      if names.any? { |name| name.include?(",") }
        errors.add(:base, I18n.t("discourse_data_explorer.errors.tag_contains_comma"))
      end
    end

    def self.sync!(query:, names:)
      names = normalize_all(names)
      names.unshift(Query::DEFAULT_TAG) if query.id.negative?
      names.uniq!
      validate_names!(query:, names:)

      desired = resolve_or_create!(names)
      desired_ids = desired.map(&:id)
      current_ids = QueryTagMapping.where(query_id: query.id).pluck(:query_tag_id)

      removed_ids = current_ids - desired_ids
      if removed_ids.present?
        QueryTagMapping.where(query_id: query.id, query_tag_id: removed_ids).delete_all
      end
      (desired_ids - current_ids).each do |query_tag_id|
        QueryTagMapping.create!(query_id: query.id, query_tag_id:)
      end

      prune!(removed_ids)
      query.association(:tags).reset
      desired
    end

    def self.prune!(tag_ids)
      return if tag_ids.blank?

      where(id: tag_ids).where.not(id: QueryTagMapping.select(:query_tag_id)).delete_all
    end

    def self.resolve_or_create!(names)
      return [] if names.blank?

      now = Time.zone.now
      insert_all(
        names.map { |name| { name:, created_at: now, updated_at: now } },
        unique_by: :idx_data_explorer_tags_on_name,
      )
      where(name: names).to_a
    end

    def self.validate_names!(query:, names:)
      errors = ActiveModel::Errors.new(query)
      validate_names(names, errors)
      if !Query.is_default_query?(query.id) && names.include?(Query::DEFAULT_TAG)
        errors.add(:base, I18n.t("discourse_data_explorer.errors.default_tag_reserved"))
      end
      return if errors.empty?

      errors.each { |error| query.errors.import(error) }
      raise ActiveRecord::RecordInvalid.new(query)
    end
  end
end

# == Schema Information
#
# Table name: data_explorer_tags
#
#  id         :bigint           not null, primary key
#  name       :string(100)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  idx_data_explorer_tags_on_name  (name) UNIQUE
#
