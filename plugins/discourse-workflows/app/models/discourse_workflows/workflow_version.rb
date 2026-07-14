# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowVersion < ActiveRecord::Base
    self.table_name = "discourse_workflows_workflow_versions"
    self.primary_key = :version_id

    belongs_to :workflow, class_name: "DiscourseWorkflows::Workflow"
    belongs_to :created_by, class_name: "User", foreign_key: "created_by_id"
    belongs_to :updated_by, class_name: "User", foreign_key: "updated_by_id", optional: true

    before_validation :assign_version_id, on: :create

    attribute :nodes, default: -> { [] }
    attribute :connections, default: -> { {} }
    attribute :settings, default: -> { {} }

    validates :version_id, presence: true, length: { maximum: 36 }
    validates :workflow_id, :version_number, :name, :created_by_id, presence: true
    validates :name, length: { maximum: 100 }

    before_destroy :prevent_destroy_if_referenced

    private

    def assign_version_id
      self.version_id ||= SecureRandom.uuid
    end

    def prevent_destroy_if_referenced
      return unless workflow
      return unless workflow.version_id == version_id || workflow.active_version_id == version_id

      errors.add(
        :base,
        I18n.t("discourse_workflows.errors.workflow_version.referenced_by_workflow"),
      )
      throw :abort
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_workflow_versions
#
#  authors        :text
#  autosaved      :boolean          default(FALSE), not null
#  connections    :jsonb            not null
#  name           :string(100)      not null
#  nodes          :jsonb            not null
#  settings       :jsonb            not null
#  version_number :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  created_by_id  :integer          not null
#  updated_by_id  :integer
#  version_id     :string(36)       not null, primary key
#  workflow_id    :bigint           not null
#
# Indexes
#
#  idx_dwf_versions_on_workflow_created_at      (workflow_id,created_at DESC)
#  idx_dwf_versions_on_workflow_id              (workflow_id)
#  idx_dwf_versions_on_workflow_version_number  (workflow_id,version_number) UNIQUE
#
