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
      @steps_journal = nil
      super
    end

    def entries
      parsed_data["entries"] || {}
    end

    def context_data
      parsed_data["context"] || {}
    end

    def steps_array
      steps_journal.serialized_steps_array
    end

    def find_step(node_id:, status: nil)
      steps_journal.find_step(node_id: node_id, status: status)&.to_h
    end

    def find_steps_by_type(node_type)
      steps_journal.find_steps_by_type(node_type).map(&:to_h)
    end

    def last_step_with_status(status)
      steps_journal.last_step_with_status(status)&.to_h
    end

    private

    def steps_journal
      @steps_journal ||= DiscourseWorkflows::Executor::StepsJournal.new(entries: entries)
    end
  end
end
