# frozen_string_literal: true

module DiscourseWorkflows
  class Execution < ActiveRecord::Base
    self.table_name = "discourse_workflows_executions"

    belongs_to :workflow, class_name: "DiscourseWorkflows::Workflow", foreign_key: "workflow_id"

    has_one :execution_data,
            class_name: "DiscourseWorkflows::ExecutionData",
            foreign_key: "execution_id",
            dependent: :destroy

    enum :status,
         { pending: 0, running: 1, success: 2, error: 3, waiting: 4, rate_limited: 5, skipped: 6 }
    enum :execution_mode, { normal: 0, error_mode: 1, manual: 2 }

    scope :for_workflow, ->(workflow_id) { workflow_id ? where(workflow_id: workflow_id) : all }
    scope :recent, ->(period = 7.days) { where("created_at >= ?", period.ago) }
    scope :successful, -> { where(status: :success) }
    scope :with_duration,
          -> { where.not(started_at: nil, finished_at: nil).where(status: %i[success error]) }

    scope :expired_waiting, -> { where(status: :waiting).where("waiting_until < ?", Time.current) }

    TERMINAL_STATUSES_FOR_PURGE = %i[success error rate_limited skipped].freeze
    PURGE_BATCH_SIZE = 5_000

    def self.create_pending_manual!(workflow:, trigger_node_id:, trigger_data:)
      transaction do
        create!(
          workflow: workflow,
          workflow_version_id: workflow.version_id,
          trigger_node_id: trigger_node_id,
          trigger_data: trigger_data,
          status: :pending,
          execution_mode: :manual,
        ).tap do |execution|
          ExecutionData.create!(
            execution: execution,
            workflow_data: WorkflowSnapshot.from_workflow(workflow, published: false).to_h,
          )
        end
      end
    end

    def self.purge_old
      retention_days = SiteSetting.workflow_executions_retention_days
      return if retention_days <= 0

      cutoff = retention_days.days.ago
      terminal_ids = statuses.values_at(*TERMINAL_STATUSES_FOR_PURGE)

      loop do
        ids =
          where(status: terminal_ids)
            .where("created_at < ?", cutoff)
            .limit(PURGE_BATCH_SIZE)
            .pluck(:id)
        break if ids.empty?

        ExecutionData.where(execution_id: ids).delete_all
        where(id: ids).delete_all
      end
    end

    def self.claim_for_resume(execution, resume_token: nil)
      scope = where(id: execution.id, status: :waiting)
      scope = scope.where(resume_token: resume_token) if resume_token

      now = Time.current
      affected = scope.update_all(status: statuses[:running], updated_at: now)
      return nil if affected.zero?

      execution.status = :running
      execution.updated_at = now
      execution
    end

    def self.claim_pending(execution)
      now = Time.current
      affected =
        where(id: execution.id, status: :pending).update_all(
          status: statuses[:running],
          started_at: now,
          updated_at: now,
        )
      return nil if affected.zero?

      execution.status = :running
      execution.started_at = now
      execution.updated_at = now
      execution
    end

    def self.compute_run_time_ms(steps)
      waiting_types = NodeType.waiting_identifiers
      timed =
        steps.select do |s|
          step_field(s, :started_at) && step_field(s, :finished_at) &&
            waiting_types.exclude?(step_field(s, :node_type))
        end
      return if timed.empty?
      total =
        timed.sum do |s|
          Time.parse(step_field(s, :finished_at).to_s) - Time.parse(step_field(s, :started_at).to_s)
        end
      (total * 1000).round
    end

    def self.step_field(step, key)
      step.is_a?(Hash) ? step[key.to_s] : step.public_send(key)
    end
    private_class_method :step_field

    def fail_with_timeout!
      message = I18n.t("discourse_workflows.errors.approval_timed_out")
      node_id = waiting_node_id
      claimed = false

      transaction do
        run_time_ms = execution_data && self.class.compute_run_time_ms(execution_data.steps_array)

        affected =
          self
            .class
            .where(id: id, status: :waiting)
            .update_all(
              status: self.class.statuses[:error],
              error: message,
              finished_at: Time.current,
              run_time_ms: run_time_ms,
              waiting_node_id: nil,
              waiting_until: nil,
              resume_token: nil,
              timeout_action: nil,
              updated_at: Time.current,
            )

        next if affected.zero?

        claimed = true
        update_step_status_in_data!(
          node_id,
          Executor::Step::WAITING,
          Executor::Step::ERROR,
          message,
        )
      end

      claimed
    end

    def waiting_step_input_items
      return [{ "json" => {} }] unless execution_data

      entries = execution_data.entries || {}
      steps = entries[waiting_node_id.to_s] || []
      waiting_step = steps.find { |s| s["status"] == "waiting" }
      waiting_step&.dig("input") || [{ "json" => {} }]
    end

    def find_waiting_node
      workflow_node(waiting_node_id)
    end

    def workflow_node(node_id)
      return workflow.find_published_node(node_id) if workflow_data.blank?

      WorkflowSnapshot.new(workflow_data).to_h["nodes"].find { |node| node["id"] == node_id.to_s }
    end

    def node_has_reachable_downstream_of_type?(node_id, type)
      if workflow_data.present?
        return(
          WorkflowSnapshot.new(workflow_data).node_has_reachable_downstream_of_type?(node_id, type)
        )
      end

      workflow.node_has_reachable_downstream_of_type?(node_id, type, published: true)
    end

    def workflow_snapshot_name
      if workflow_data.present?
        snapshot_name = WorkflowSnapshot.new(workflow_data).workflow_name
        return snapshot_name if snapshot_name.present?
      end

      workflow.active_version&.name || workflow.name
    end

    private

    def workflow_data
      execution_data&.workflow_data
    end

    def update_step_status_in_data!(node_id, from_status, to_status, error_msg = nil)
      return unless execution_data

      full_data = execution_data.data.deep_dup
      (full_data["entries"] || {}).each_value do |steps|
        Array(steps).each do |step|
          if step["node_id"] == node_id.to_s && step["status"] == from_status.to_s
            step["status"] = to_status.to_s
            step["error"] = error_msg if error_msg
            step["finished_at"] = Time.current.iso8601
          end
        end
      end
      execution_data.update!(data: full_data)
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_executions
#
#  id                  :bigint           not null, primary key
#  error               :text
#  execution_mode      :integer          default("normal"), not null
#  finished_at         :datetime
#  resume_token        :string(64)
#  run_time_ms         :integer
#  started_at          :datetime
#  status              :integer          default("pending"), not null
#  timeout_action      :string(32)
#  trigger_data        :jsonb
#  waiting_until       :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  trigger_node_id     :string(100)
#  waiting_node_id     :string(100)
#  workflow_id         :bigint           not null
#  workflow_version_id :string(36)       not null
#
# Indexes
#
#  idx_dwf_executions_on_resume_token                 (resume_token) WHERE (resume_token IS NOT NULL)
#  idx_dwf_executions_on_retention                    (created_at) WHERE (status = ANY (ARRAY[2, 3, 5, 6]))
#  idx_dwf_executions_on_status_waiting_until         (status,waiting_until)
#  idx_dwf_executions_on_waiting_until                (waiting_until) WHERE ((waiting_until IS NOT NULL) AND (status = 4))
#  idx_dwf_executions_on_workflow_created_at_id_desc  (workflow_id,created_at DESC,id DESC)
#  idx_dwf_executions_on_workflow_version_id          (workflow_version_id)
#
