# frozen_string_literal: true

module DiscourseAutomation
  class PendingAutomation < ActiveRecord::Base
    self.table_name = "discourse_automation_pending_automations"

    belongs_to :automation, class_name: "DiscourseAutomation::Automation"
  end
end
