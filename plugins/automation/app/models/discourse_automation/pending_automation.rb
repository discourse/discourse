# frozen_string_literal: true

module DiscourseAutomation
  class PendingAutomation < ActiveRecord::Base
    self.table_name = "discourse_automation_pending_automations"

    belongs_to :automation, class_name: "DiscourseAutomation::Automation"
  end
end

# == Schema Information
#
# Table name: discourse_automation_pending_automations
#
#  id            :bigint           not null, primary key
#  automation_id :bigint           not null
#  execute_at    :datetime         not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
