# frozen_string_literal: true

class PostFlag < ActiveRecord::Base
  scope :enabled, -> { where(enabled: true) }

  before_create :set_custom_id, unless: :system?
  before_save :set_position
  after_save :reset_post_action_types!
  after_destroy :reset_post_action_types!

  def used?
    PostAction.exists?(post_action_type_id: self.id)
  end

  def self.reset_post_action_types!
    PostActionType.initialize_flag_settings
  end

  private

  def reset_post_action_types!
    self.class.reset_post_action_types!
  end

  def set_custom_id
    return if self.id.to_i > 1000
    self.id = PostFlag.maximum(:id).next
    self.id += 1000
  end

  def set_position
    self.position = PostFlag.maximum(:position).to_i + 1 if !self.position
  end
end

# == Schema Information
#
# Table name: post_flags
#
#  id               :bigint           not null, primary key
#  name             :string
#  position         :integer          not null
#  system           :boolean          not null
#  enabled          :boolean          default(TRUE), not null
#  topic_type       :boolean          default(FALSE), not null
#  notify_type      :boolean          default(FALSE), not null
#  auto_action_type :boolean          default(FALSE), not null
#  custom_type      :boolean          default(FALSE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
