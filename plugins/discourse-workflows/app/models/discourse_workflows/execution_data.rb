# frozen_string_literal: true

module DiscourseWorkflows
  class ExecutionData < ActiveRecord::Base
    self.table_name = "discourse_workflows_execution_data"
    self.primary_key = "execution_id"

    belongs_to :execution, class_name: "DiscourseWorkflows::Execution", foreign_key: "execution_id"

    def parsed_data
      @parsed_data ||= data.present? ? JSON.parse(data) : {}
    end

    def data=(value)
      @parsed_data = nil
      @all_steps = nil
      super
    end

    def entries
      parsed_data["entries"] || {}
    end

    def context_data
      parsed_data["context"] || {}
    end

    def node_contexts
      parsed_data["node_contexts"] || {}
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

    def find_steps_by_type(node_type)
      all_steps.select { |step| step["node_type"] == node_type }
    end

    def last_step_with_status(status)
      status_str = status.to_s
      all_steps.reverse_each.find { |step| step["status"] == status_str }
    end

    private

    def all_steps
      @all_steps ||= entries.values.flatten
    end
  end
end
