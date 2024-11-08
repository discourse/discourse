# frozen_string_literal: true

class Flag < ActiveRecord::Base
  # TODO(2025-01-15): krisk remove
  self.ignored_columns = ["custom_type"]

  DEFAULT_VALID_APPLIES_TO = %w[Post Topic].freeze
  MAX_SYSTEM_FLAG_ID = 1000
  MAX_NAME_LENGTH = 200
  MAX_DESCRIPTION_LENGTH = 1000
  scope :enabled, -> { where(enabled: true) }
  scope :system, -> { where("id < 1000") }
  scope :custom, -> { where("id >= 1000") }

  before_save :set_position
  before_save :set_name_key
  after_commit { reset_flag_settings! if !skip_reset_flag_callback }

  attr_accessor :skip_reset_flag_callback

  default_scope do
    order(:position).where(score_type: false).where.not(id: PostActionType::LIKE_POST_ACTION_ID)
  end

  def used?
    PostAction.exists?(post_action_type_id: self.id) ||
      ReviewableScore.exists?(reviewable_score_type: self.id)
  end

  def self.valid_applies_to_types
    Set.new(DEFAULT_VALID_APPLIES_TO | DiscoursePluginRegistry.flag_applies_to_types)
  end

  def self.reset_flag_settings!
    # Flags are cached in Redis for better performance. After the update,
    # we need to reload them in all processes.
    PostActionType.reload_types
  end

  def self.used_flag_ids
    PostAction.distinct(:post_action_type_id).pluck(:post_action_type_id) |
      ReviewableScore.distinct(:reviewable_score_type).pluck(:reviewable_score_type)
  end

  def system?
    self.id.present? && self.id < MAX_SYSTEM_FLAG_ID
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
    prefix = self.system? ? "" : "custom_"
    self.name_key = "#{prefix}#{self.name.squeeze(" ").gsub(" ", "_").gsub(/[^\w]/, "").downcase}"
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
#  require_message  :boolean          default(FALSE), not null
#  applies_to       :string           not null, is an Array
#  position         :integer          not null
#  enabled          :boolean          default(TRUE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  score_type       :boolean          default(FALSE), not null
#
