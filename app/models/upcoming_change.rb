# frozen_string_literal: true

class UpcomingChange < ActiveRecord::Base
  def self.risk_levels
    @risk_levels ||= Enum.new(low: 0, medium: 1, high: 2)
  end

  def self.statuses
    @statuses ||= Enum.new(alpha: 0, beta: 1, stable: 2)
  end

  def self.change_types
    @change_types ||= Enum.new(feature: 0, other: 1)
  end

  belongs_to :enabled_by, class_name: "User", optional: true

  validates :identifier, presence: true, uniqueness: true
  validates :description, presence: true
  validates :risk_level, presence: true, inclusion: { in: risk_levels.values }
  validates :status, presence: true, inclusion: { in: statuses.values }
  validates :change_type, presence: true, inclusion: { in: change_types.values }
end

# == Schema Information
#
# Table name: upcoming_changes
#
#  id                 :bigint           not null, primary key
#  change_type        :integer          default(0), not null
#  description        :string           not null
#  enabled            :boolean          default(FALSE), not null
#  identifier         :string           not null
#  plugin_identifier  :string
#  promote_at_version :string
#  risk_level         :integer          default(0), not null
#  status             :integer          default(0), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  enabled_by_id      :bigint
#  meta_topic_id      :integer
#
# Indexes
#
#  index_upcoming_changes_on_enabled_by_id      (enabled_by_id)
#  index_upcoming_changes_on_identifier         (identifier) UNIQUE
#  index_upcoming_changes_on_plugin_identifier  (plugin_identifier)
#
