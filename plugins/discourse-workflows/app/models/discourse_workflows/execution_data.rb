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
      super
    end

    def run_data
      rd = parsed_data["run_data"]
      # Legacy format stored run data at the top level without a "run_data" wrapper.
      # If the key is missing or not a Hash, fall back to the full parsed data.
      return rd if rd.is_a?(Hash)
      parsed_data
    end

    def context_data
      parsed_data["context"] || {}
    end

    def steps_array
      run_data.flat_map { |_node_name, steps| Array(steps) }.sort_by { |s| s["position"] || 0 }
    end

    def find_step(node_id:, status: nil)
      node_id_str = node_id.to_s
      run_data.each_value do |steps|
        Array(steps).each do |step|
          next if step["node_id"] != node_id_str
          next if status && step["status"] != status.to_s
          return step
        end
      end
      nil
    end

    def find_steps_by_type(node_type)
      run_data.flat_map { |_name, steps| Array(steps).select { |s| s["node_type"] == node_type } }
    end

    def last_step_with_status(status)
      steps_array.reverse_each.find { |s| s["status"] == status.to_s }
    end
  end
end
