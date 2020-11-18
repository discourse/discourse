# frozen_string_literal: true

module DiscourseAutomation
  class Field < ActiveRecord::Base
    self.table_name = 'discourse_automation_fields'

    belongs_to :automation, class_name: 'DiscourseAutomation::Automation'
  end
end
