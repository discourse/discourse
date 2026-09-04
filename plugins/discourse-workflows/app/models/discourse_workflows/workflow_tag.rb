# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTag < ActiveRecord::Base
    self.table_name = "discourse_workflows_tags"

    MAX_TAGS_PER_WORKFLOW = 10
    MAX_NAME_LENGTH = 100

    has_many :workflow_tag_mappings,
             class_name: "DiscourseWorkflows::WorkflowTagMapping",
             foreign_key: "workflow_tag_id",
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

    class << self
      def normalize_name(name)
        name.to_s.strip.downcase.gsub(/[[:space:]]+/, " ")
      end

      def normalize_all(names)
        Array.wrap(names).map { |name| normalize_name(name) }.reject(&:blank?).uniq
      end

      def validate_names(names, errors)
        if names.size > MAX_TAGS_PER_WORKFLOW
          errors.add(
            :base,
            I18n.t("discourse_workflows.errors.too_many_tags", max: MAX_TAGS_PER_WORKFLOW),
          )
        end

        if names.any? { |name| name.length > MAX_NAME_LENGTH }
          errors.add(:base, I18n.t("discourse_workflows.errors.tag_too_long", max: MAX_NAME_LENGTH))
        end

        if names.any? { |name| name.include?(",") }
          errors.add(:base, I18n.t("discourse_workflows.errors.tag_contains_comma"))
        end
      end

      def resolve_or_create!(names)
        return [] if names.blank?

        now = Time.zone.now
        insert_all(
          names.map { |name| { name:, created_at: now, updated_at: now } },
          unique_by: :idx_dwf_tags_on_name,
        )
        where(name: names).to_a
      end

      def sync!(workflow:, names:)
        desired = resolve_or_create!(normalize_all(names))
        desired_ids = desired.map(&:id)
        current_ids = WorkflowTagMapping.where(workflow_id: workflow.id).pluck(:workflow_tag_id)

        removed_ids = current_ids - desired_ids
        if removed_ids.present?
          WorkflowTagMapping.where(
            workflow_id: workflow.id,
            workflow_tag_id: removed_ids,
          ).delete_all
        end
        (desired_ids - current_ids).each do |workflow_tag_id|
          WorkflowTagMapping.create!(workflow_id: workflow.id, workflow_tag_id:)
        end

        prune!(removed_ids)
        workflow.association(:tags).reset
        desired
      end

      def prune!(tag_ids)
        return if tag_ids.blank?

        where(id: tag_ids).where.not(id: WorkflowTagMapping.select(:workflow_tag_id)).delete_all
      end
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_tags
#
#  id         :bigint           not null, primary key
#  name       :string(100)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  idx_dwf_tags_on_name  (name) UNIQUE
#
