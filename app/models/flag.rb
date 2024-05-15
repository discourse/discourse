# frozen_string_literal: true

class Flag < ActiveRecord::Base
  scope :enabled, -> { where(enabled: true) }
  scope :system, -> { where(system: true) }

  before_save :set_position
  before_save :set_name_key
  after_save :reset_flag_settings!
  after_destroy :reset_flag_settings!

  def used?
    PostAction.exists?(post_action_type_id: self.id) ||
      ReviewableScore.exists?(reviewable_score_type: self.id)
  end

  def self.reset_flag_settings!
    PostActionType.reload_types
    ReviewableScore.reload_types
  end

  def system?
    self.id < 1000
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
    self.name_key = self.name.gsub(" ", "_").gsub(/[^\w]/, "").downcase
  end
end

# == Schema Information
#
# Table name: flags
#
#  id               :bigint           not null, primary key
#  name             :string
#  position         :integer          not null
#  enabled          :boolean          default(TRUE), not null
#  topic_type       :boolean          default(FALSE), not null
#  notify_type      :boolean          default(FALSE), not null
#  auto_action_type :boolean          default(FALSE), not null
#  custom_type      :boolean          default(FALSE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
