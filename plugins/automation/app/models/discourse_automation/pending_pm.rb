# frozen_string_literal: true

module DiscourseAutomation
  class PendingPm < ActiveRecord::Base
    # TODO: Remove after 20260106102330_drop_prefers_encrypt_from_pending_pms has been promoted
    # TODO (2026-08-11): Remove sender and target_usernames after column drop migration has been promoted
    self.ignored_columns = %w[prefers_encrypt sender target_usernames]

    self.table_name = "discourse_automation_pending_pms"

    belongs_to :automation, class_name: "DiscourseAutomation::Automation"
  end
end

# == Schema Information
#
# Table name: discourse_automation_pending_pms
#
#  id               :bigint           not null, primary key
#  execute_at       :datetime         not null
#  raw              :string
#  sender           :string
#  target_usernames :string           is an Array
#  title            :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  automation_id    :bigint           not null
#
