# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTest < ActiveRecord::Base
    self.table_name = "discourse_workflows_workflow_tests"

    MAX_PER_WORKFLOW = 25
    MAX_DEFINITION_BYTES = 256.kilobytes
    STATES = %w[passed failed could_not_run not_run run_again running].freeze

    belongs_to :workflow, class_name: "DiscourseWorkflows::Workflow", foreign_key: "workflow_id"
    belongs_to :created_by, class_name: "User", foreign_key: "created_by_id"
    belongs_to :updated_by, class_name: "User", foreign_key: "updated_by_id"
    belongs_to :source_execution,
               class_name: "DiscourseWorkflows::Execution",
               foreign_key: "source_execution_id",
               optional: true
    belongs_to :latest_execution,
               class_name: "DiscourseWorkflows::Execution",
               foreign_key: "latest_execution_id",
               optional: true

    attribute :trigger_data, default: -> { {} }
    attribute :captured_outputs, default: -> { {} }
    attribute :pasted_responses, default: -> { {} }
    attribute :checks, default: -> { [] }

    validates :name, presence: true, length: { maximum: 100 }
    validates :trigger_node_id, :trigger_type, presence: true
    validate :checks_are_valid
    validate :definition_within_limit

    before_validation :assign_definition_digest
    before_destroy :detach_executions

    def self.definition_digest_for(trigger_data:, pasted_responses:, checks:)
      CanonicalDigest.of(
        {
          "trigger_data" => trigger_data,
          "pasted_responses" => pasted_responses,
          "checks" => checks,
        },
      )
    end

    def checks=(value)
      super(WorkflowTestChecks.normalize(value))
    end

    def result
      latest_execution&.execution_data&.test_result
    end

    def simulation
      latest_execution&.execution_data&.simulation
    end

    def running?
      latest_execution.present? && (latest_execution.pending? || latest_execution.running?)
    end

    def captured?
      captured_at.present?
    end

    def result_current?
      latest_execution.present? && latest_execution.workflow_test_digest == definition_digest &&
        latest_execution.workflow_version_id == workflow.version_id &&
        latest_execution.pin_data_digest == workflow.pin_data_digest
    end

    def state
      return "not_run" if latest_execution.nil?
      return "running" if running?
      return "could_not_run" if result.nil? || result["status"] == "could_not_run"
      return "run_again" unless result_current?

      result["status"]
    end

    def reason
      return if running? || latest_execution.nil?
      return result["reason"] if result

      latest_execution.error
    end

    def replay_steps
      workflow.nodes.filter_map do |node|
        declaration =
          Registry.find_node_type(
            node["type"],
            version: NodeData.type_version(node),
          )&.simulation_declaration
        next unless declaration&.replays?

        name = node["name"].to_s
        external = declaration.records?
        captured = captured_outputs.keys.any? { |key| key.start_with?("#{name}:") }
        {
          "name" => name,
          "type" => node["type"],
          "kind" => external ? "external" : "lookup",
          "captured" => captured,
          "pasted" => pasted_responses.key?(name),
          "needs_response" => external && !captured && !pasted_responses.key?(name),
        }
      end
    end

    def steps_needing_response
      replay_steps.select { |step| step["needs_response"] }.map { |step| step["name"] }
    end

    def record_captures!(execution, captures, pinned_at:)
      with_lock do
        return unless latest_execution_id == execution.id

        merged = captured_outputs.deep_dup
        captures.each do |key, entries|
          merged[key] ||= []
          entries.each_with_index do |entry, index|
            next if entry.nil?
            next if merged[key][index].present? && merged[key][index]["fingerprint"].present?

            merged[key][index] = entry
          end
        end
        update!(captured_outputs: merged, captured_at: captured_at || pinned_at)
      end
    end

    private

    def assign_definition_digest
      self.definition_digest =
        self.class.definition_digest_for(trigger_data:, pasted_responses:, checks:)
    end

    def checks_are_valid
      WorkflowTestChecks.errors_for(checks).each { |message| errors.add(:checks, message) }
    end

    def definition_within_limit
      bytes =
        JSON.generate({ trigger_data:, pasted_responses:, checks:, captured_outputs: }).bytesize
      return if bytes <= MAX_DEFINITION_BYTES

      errors.add(:base, I18n.t("discourse_workflows.tests.errors.definition_too_large"))
    end

    def detach_executions
      Execution.where(workflow_test_id: id).update_all(workflow_test_id: nil)
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_workflow_tests
#
#  id                   :bigint           not null, primary key
#  captured_at          :datetime
#  captured_outputs     :jsonb            not null
#  checks               :jsonb            not null
#  definition_digest    :string(64)       not null
#  name                 :string(100)      not null
#  pasted_responses     :jsonb            not null
#  trigger_data         :jsonb            not null
#  trigger_type         :string           not null
#  trigger_type_version :integer          default(1), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  created_by_id        :bigint           not null
#  latest_execution_id  :bigint
#  source_execution_id  :bigint           not null
#  trigger_node_id      :string           not null
#  updated_by_id        :bigint           not null
#  workflow_id          :bigint           not null
#
# Indexes
#
#  idx_dwf_workflow_tests_on_workflow_created_at  (workflow_id,created_at)
#
