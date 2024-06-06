# frozen_string_literal: true

class Flag < ActiveRecord::Base
  MAX_SYSTEM_FLAG_ID = 1000
  scope :enabled, -> { where(enabled: true) }
  scope :system, -> { where("id < 1000") }

  before_save :set_position
  before_save :set_name_key
  after_save :reset_flag_settings!
  after_destroy :reset_flag_settings!

  default_scope { order(:position).where(score_type: false) }

  def used?
    PostAction.exists?(post_action_type_id: self.id) ||
      ReviewableScore.exists?(reviewable_score_type: self.id)
  end

  def self.reset_flag_settings!
    # Flags are memoized for better performance. After the update, we need to reload them in all processes.
    PostActionType.reload_types
    DiscourseEvent.trigger(:reload_post_action_types)
  end

  def system?
    self.id < MAX_SYSTEM_FLAG_ID
  end

  def applies_to?(type)
    self.applies_to.include?(type)
  end

  private

  def reset_flag_settings!
    self.class.reset_flag_settings!
  end

  def set_position
    self.position = Flag.maximum(:position).to_i + 1 if !self.position
  end

  def set_name_key
    self.name_key = self.name.squeeze(" ").gsub(" ", "_").gsub(/[^\w]/, "").downcase
  end
end

# == Schema Information
#
# Table name: flags
#
#  id               :bigint           not null, primary key
#  name             :string
#  name_key         :string
#  description      :text
#  notify_type      :boolean          default(FALSE), not null
#  auto_action_type :boolean          default(FALSE), not null
#  custom_type      :boolean          default(FALSE), not null
#  applies_to       :string           not null, is an Array
#  position         :integer          not null
#  enabled          :boolean          default(TRUE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  score_type       :boolean          default(FALSE), not null
#
