# frozen_string_literal: true

module DiscourseWorkflows
  class ExecutionData < ActiveRecord::Base
    self.table_name = "discourse_workflows_execution_data"
    self.primary_key = "execution_id"

    attribute :data,
              default: -> do
                { "entries" => {}, "context" => {}, "node_contexts" => {}, "run_data" => {} }
              end

    belongs_to :execution, class_name: "DiscourseWorkflows::Execution", foreign_key: "execution_id"

    def entries
      data["entries"] || {}
    end

    def context_data
      data["context"] || {}
    end

    def node_contexts
      data["node_contexts"] || {}
    end

    def run_data
      data["run_data"] || {}
    end

    def steps_array
      all_steps.sort_by { |s| s["position"] || 0 }
    end

    def find_step(node_id:, status: nil)
      node_id_str = node_id.to_s
      all_steps.find do |step|
        step["node_id"] == node_id_str && (!status || step["status"] == status.to_s)
      end
    end

    def last_step_with_status(status)
      status_str = status.to_s
      all_steps.reverse_each.find { |step| step["status"] == status_str }
    end

    private

    def all_steps
      entries.values.flatten
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_execution_data
#
#  data          :jsonb            not null
#  workflow_data :jsonb            not null
#  execution_id  :bigint           not null, primary key
#
# Indexes
#
#  idx_dwf_execution_data_on_execution_id  (execution_id) UNIQUE
#
