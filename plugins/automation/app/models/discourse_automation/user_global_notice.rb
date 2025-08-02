# frozen_string_literal: true

module DiscourseAutomation
  class UserGlobalNotice < ActiveRecord::Base
    self.table_name = "discourse_automation_user_global_notices"

    belongs_to :user
  end
end

# == Schema Information
#
# Table name: discourse_automation_user_global_notices
#
#  id         :bigint           not null, primary key
#  user_id    :integer          not null
#  notice     :text             not null
#  identifier :string           not null
#  level      :string           default("info")
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  idx_discourse_automation_user_global_notices  (user_id,identifier) UNIQUE
#
