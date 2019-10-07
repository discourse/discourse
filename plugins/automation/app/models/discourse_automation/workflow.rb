# frozen_string_literal: true

module DiscourseAutomation
  class Workflow < ActiveRecord::Base
    self.table_name = 'discourse_automation_workflows'

    validates_presence_of :name

    has_many :plans
    has_one :trigger

    def self.enqueue_workflows(identifier, args = {})
      identifier = Trigger.identifiers[identifier.to_sym]

      Workflow
        .joins(:trigger)
        .where('discourse_automation_triggers.identifier = ?', identifier)
        .find_each do |workflow|
          default_args = { workflow_id: workflow.id }

          Jobs.enqueue(
            :discourse_automation_process_workflow,
            default_args.merge(args)
          )
        end
    end
  end
end
