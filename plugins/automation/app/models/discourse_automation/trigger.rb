# frozen_string_literal: true

module DiscourseAutomation
  class Trigger < ActiveRecord::Base
    self.table_name = 'discourse_automation_triggers'

    belongs_to :workflow

    enum identifier: {
      on_user_created: 1,
      on_group_joined: 2,
      every_ten_minutes: 3,
      every_hour: 4,
      every_day: 5
    }

    validates_presence_of :identifier

    def triggerable
      Triggerable[identifier]
    end

    validate :validates_options
    def validates_options
      fields = triggerable[:fields]

      fields.each do |field_name, field_options|
        if field_options[:required] &&
           options[field_name.to_s].blank?
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
