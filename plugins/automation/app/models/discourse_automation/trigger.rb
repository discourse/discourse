# frozen_string_literal: true

module DiscourseAutomation
  class Trigger < ActiveRecord::Base
    POINT_IN_TIME = 'point-in-time'
    USER_JOINED_GROUP = 'user-joined-group'

    self.table_name = 'discourse_automation_triggers'

    belongs_to :automation, class_name: 'DiscourseAutomation::Automation'

    def update_with_params(params)
      automation.reset!

      update!(params)

      trigger = DiscourseAutomation::Triggerable.new(automation)
      trigger.on_update.call(automation, params[:metadata])
    end

    def run!(trigger)
      scriptable = DiscourseAutomation::Scriptable.new(automation)

      fields = automation
        .fields
        .pluck(:name, :metadata)
        .reduce({}) do |acc, hash|
          name, field = hash
          acc[name] = field
          acc
        end

      scriptable.script.call(trigger, fields)
    end
  end
end
