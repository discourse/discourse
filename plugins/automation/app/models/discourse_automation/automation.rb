# frozen_string_literal: true

module DiscourseAutomation
  class Automation < ActiveRecord::Base
    self.table_name = 'discourse_automation_automations'

    has_many :fields, class_name: 'DiscourseAutomation::Field', dependent: :delete_all, foreign_key: 'automation_id'
    has_many :pending_automations, class_name: 'DiscourseAutomation::PendingAutomation', dependent: :delete_all, foreign_key: 'automation_id'
    has_many :pending_pms, class_name: 'DiscourseAutomation::PendingPm', dependent: :delete_all, foreign_key: 'automation_id'
    has_one :trigger, class_name: 'DiscourseAutomation::Trigger', dependent: :destroy, foreign_key: 'automation_id'

    validates :script, presence: true

    MIN_NAME_LENGTH = 5
    MAX_NAME_LENGTH = 30
    validates :name, length: { in: MIN_NAME_LENGTH..MAX_NAME_LENGTH }

    def reset!
      pending_automations.destroy_all
      pending_pms.destroy_all
    end
  end
end
