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
    enum :execution_mode, { normal: 0, error_mode: 1 }

    scope :for_workflow, ->(workflow_id) { workflow_id ? where(workflow_id: workflow_id) : all }
    scope :recent, ->(period = 7.days) { where("created_at >= ?", period.ago) }
    scope :successful, -> { where(status: :success) }
    scope :with_duration,
          -> { where.not(started_at: nil, finished_at: nil).where(status: %i[success error]) }

    scope :expired_waiting, -> { where(status: :waiting).where("waiting_until < ?", Time.current) }

    scope :waiting_with_type,
          ->(type) { where(status: :waiting).where("waiting_config->>'wait_type' = ?", type.to_s) }

    scope :by_resume_token,
          ->(token) do
            where(status: :waiting).where("waiting_config->>'resume_token' = ?", token.to_s)
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

      transaction do
        attrs = {
          status: :error,
          error: message,
          finished_at: Time.current,
          waiting_node_id: nil,
          waiting_until: nil,
          waiting_config: {
          },
        }

        if execution_data
          attrs[:run_time_ms] = self.class.compute_run_time_ms(execution_data.steps_array)
        end

        update!(attrs)

        update_step_status_in_data!(
          node_id,
          Executor::Step::WAITING,
          Executor::Step::ERROR,
          message,
        )
      end
    end

    def waiting_step_input_items
      return [{ "json" => {} }] unless execution_data

      entries = execution_data.entries || {}
      steps = entries[waiting_node_id.to_s] || []
      waiting_step = steps.find { |s| s["status"] == "waiting" }
      waiting_step&.dig("input") || [{ "json" => {} }]
    end

    def accumulated_form_data
      return {} unless execution_data
      execution_data
        .steps_array
        .each_with_object({}) do |step, data|
          form_data = step.dig("output", 0, "json", "form_data")
          data.merge!(form_data) if form_data
        end
    end

    private

    def update_step_status_in_data!(node_id, from_status, to_status, error_msg = nil)
      return unless execution_data

      full_data = execution_data.parsed_data
      rd = execution_data.entries
      rd.each_value do |steps|
        Array(steps).each do |step|
          if step["node_id"] == node_id.to_s && step["status"] == from_status.to_s
            step["status"] = to_status.to_s
            step["error"] = error_msg if error_msg
            step["finished_at"] = Time.current.iso8601
          end
        end
      end
      execution_data.update!(data: full_data.to_json)
    end
  end
end
