# frozen_string_literal: true

module DiscourseAutomation
  class PendingPm < ActiveRecord::Base
    # TODO: Remove after 20260106102330_drop_prefers_encrypt_from_pending_pms has been promoted
    self.ignored_columns = %w[prefers_encrypt]

    self.table_name = "discourse_automation_pending_pms"

    belongs_to :automation, class_name: "DiscourseAutomation::Automation"
  end
end

# == Schema Information
#
# Table name: discourse_automation_pending_pms
#
#  id               :bigint           not null, primary key
#  target_usernames :string           is an Array
#  sender           :string
#  title            :string
#  raw              :string
#  automation_id    :bigint           not null
#  execute_at       :datetime         not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  prefers_encrypt  :boolean          default(FALSE), not null
#
