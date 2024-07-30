# frozen_string_literal: true

module DiscourseAutomation
  class PendingPm < ActiveRecord::Base
    self.table_name = "discourse_automation_pending_pms"

    belongs_to :automation, class_name: "DiscourseAutomation::Automation"
  end
end
