# frozen_string_literal: true

class WebHookEventType < ActiveRecord::Base
  TOPIC = 1
  POST = 2
  USER = 3
  GROUP = 4
  CATEGORY = 5
  TAG = 6
  REVIEWABLE = 9
  NOTIFICATION = 10
  SOLVED = 11
  ASSIGN = 12
  USER_BADGE = 13
  GROUP_USER = 14
  LIKE = 15
  USER_PROMOTED = 16
  TOPIC_VOTING = 17

  has_and_belongs_to_many :web_hooks

  default_scope { order("id ASC") }

  validates :name, presence: true, uniqueness: true

  def self.active
    ids_to_exclude = []
    unless defined?(SiteSetting.solved_enabled) && SiteSetting.solved_enabled
      ids_to_exclude << SOLVED
    end
    unless defined?(SiteSetting.assign_enabled) && SiteSetting.assign_enabled
      ids_to_exclude << ASSIGN
    end
    unless defined?(SiteSetting.voting_enabled) && SiteSetting.voting_enabled
      ids_to_exclude << TOPIC_VOTING
    end

    self.where.not(id: ids_to_exclude)
  end
end

# == Schema Information
#
# Table name: web_hook_event_types
#
#  id   :integer          not null, primary key
#  name :string           not null
#
