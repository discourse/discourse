# frozen_string_literal: true

module DiscourseAutomation
  class Trigger < ActiveRecord::Base
    POINT_IN_TIME = 'point-in-time'

    self.table_name = 'discourse_automation_triggers'

    belongs_to :automation, class_name: 'DiscourseAutomation::Automation'

    def point_in_time_after_update(_params)
      automation.pending_automations.create!(execute_at: metadata['execute_at'])
    end

    def update_with_params(params)
      automation.pending_automations.destroy_all
      update!(params)
      public_send("#{name.underscore}_after_update", params)
    end
  end
end
