# frozen_string_literal: true

class Flag < ActiveRecord::Base
  scope :enabled, -> { where(enabled: true) }

  before_save :set_position
  after_save :reset_flag_settings!
  after_destroy :reset_flag_settings!

  def used?
    PostAction.exists?(post_action_type_id: self.id)
  end

  def self.reset_flag_settings!
    PostActionType.initialize_flag_settings
  end

  def system?
    self.id < 1000
  end

  private

  def reset_flag_settings!
    self.class.reset_flag_settings!
  end

  def set_position
    self.position = Flag.maximum(:position).to_i + 1 if !self.position
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
