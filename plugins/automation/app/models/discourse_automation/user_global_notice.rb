# frozen_string_literal: true

module DiscourseAutomation
  class UserGlobalNotice < ActiveRecord::Base
    self.table_name = 'discourse_automation_user_global_notices'

    belongs_to :user
  end
end
