# frozen_string_literal: true

module DiscourseWorkflows
  class AiAuthoringSession < ActiveRecord::Base
    self.table_name = "discourse_workflows_ai_authoring_sessions"

    STATUSES = %w[
      drafting
      generating
      needs_clarification
      proposal_ready
      applied
      error
      cancelled
    ].freeze

    RISK_LEVELS = %w[low medium high].freeze

    belongs_to :workflow,
               class_name: "DiscourseWorkflows::Workflow",
               foreign_key: "workflow_id",
               optional: true
    belongs_to :user

    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :risk_level, inclusion: { in: RISK_LEVELS }, allow_nil: true
    validate :json_fields_have_expected_shape

    scope :expired_applied_or_inactive,
          -> { where(status: %w[applied error cancelled]).where("updated_at < ?", 30.days.ago) }
    scope :expired_unapplied_proposals,
          -> { where(status: "proposal_ready").where("updated_at < ?", 7.days.ago) }

    def append_message!(type:, content:)
      self.messages = messages + [{ "type" => type.to_s, "content" => content.to_s }]
      save!
    end

    private

    def json_fields_have_expected_shape
      errors.add(:messages, :invalid) if !messages.is_a?(Array)
      errors.add(:latest_response, :invalid) if !latest_response.is_a?(Hash)
      errors.add(:proposed_patch, :invalid) if !proposed_patch.is_a?(Hash)
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_ai_authoring_sessions
#
#  id                       :bigint           not null, primary key
#  applied_at               :datetime
#  base_graph_digest        :string(64)
#  latest_request           :text
#  latest_response          :jsonb            not null
#  messages                 :jsonb            not null
#  proposed_patch           :jsonb            not null
#  risk_level               :string(20)
#  status                   :string(40)       default("drafting"), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  base_workflow_version_id :string(36)
#  user_id                  :integer          not null
#  workflow_id              :bigint
#
# Indexes
#
#  idx_dwf_ai_sessions_on_status_updated_at  (status,updated_at)
#  idx_dwf_ai_sessions_on_user_id            (user_id)
#  idx_dwf_ai_sessions_on_workflow_id        (workflow_id)
#
