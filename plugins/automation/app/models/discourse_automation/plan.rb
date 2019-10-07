# frozen_string_literal: true

module DiscourseAutomation
  class Plan < ActiveRecord::Base
    self.table_name = 'discourse_automation_plans'

    belongs_to :workflow

    enum identifier: {
      send_personal_message: 1,
      publish_random_topic: 2
    }

    def plannable
      Plannable[identifier]
    end

    validate :validates_options
    def validates_options
      fields = plannable[:fields]
      triggerable = Triggerable[workflow.trigger.identifier]
      provided = triggerable[:provided]

      fields.each do |field_name, field_options|
        if field_options[:required] &&
           field.present? &&
           !field[:value].present?
           !provided.include?(field_name)
          if field_options[:default].present?
            options[field_name.to_s] = field_options[:default]
          else
            errors.add(field_name, 'can’t be blank')
          end
        end
      end
    end
  end
end
