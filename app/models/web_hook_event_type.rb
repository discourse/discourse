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
  CHAT_MESSAGE = 18

  enum group: {
         topic: 0,
         post: 1,
         user: 2,
         group: 3,
         category: 4,
         tag: 5,
         reviewable: 6,
         notification: 7,
         solved: 8,
         assign: 9,
         user_badge: 10,
         group_user: 11,
         like: 12,
         user_promoted: 13,
         voting: 14,
         chat: 15,
       },
       _scopes: false

  TYPES = {
    topic: {
      created: 101,
      revised: 102,
      edited: 103,
      destroyed: 104,
      recovered: 105,
    },
    post: {
      created: 201,
      edited: 202,
      destroyed: 203,
      recovered: 204,
    },
    user: {
      logged_in: 301,
      logged_out: 302,
      confirmed_email: 303,
      created: 304,
      approved: 305,
      updated: 306,
      destroyed: 307,
    },
    group: {
      created: 401,
      updated: 402,
      destroyed: 403,
    },
    category: {
      created: 501,
      updated: 502,
      destroyed: 503,
    },
    tag: {
      created: 601,
      updated: 602,
      destroyed: 603,
    },
    reviewable: {
      created: 901,
      updated: 902,
    },
    notification: {
      created: 1001,
    },
    solved: {
      accepted_solution: 1101,
      unaccepted_solution: 1102,
    },
    assign: {
      assigned: 1201,
      unassigned: 1202,
    },
    user_badge: {
      granted: 1301,
      revoked: 1302,
    },
    group_user: {
      added: 1401,
      removed: 1402,
    },
    like: {
      created: 1501,
    },
    user_promoted: {
      created: 1601,
    },
    voting: {
      topic_upvote: 1701,
    },
    chat: {
      message_created: 1801,
      message_edited: 1802,
      message_trashed: 1803,
      message_restored: 1804,
    },
  }

  has_and_belongs_to_many :web_hooks

  default_scope { order("id ASC") }

  validates :name, presence: true, uniqueness: true

  scope :active_grouped, -> { active.where.not(group: nil).group_by(&:group) }

  def self.active
    ids_to_exclude = []
    unless defined?(SiteSetting.solved_enabled) && SiteSetting.solved_enabled
      ids_to_exclude << TYPES[:solved][:accept_unaccept]
    end
    unless defined?(SiteSetting.assign_enabled) && SiteSetting.assign_enabled
      ids_to_exclude << TYPES[:assign][:assign_unassign]
    end
    unless defined?(SiteSetting.voting_enabled) && SiteSetting.voting_enabled
      ids_to_exclude << TYPES[:voting][:voted_unvoted]
    end
    unless defined?(SiteSetting.chat_enabled) && SiteSetting.chat_enabled
      ids_to_exclude << TYPES[:chat][:message]
    end
    self.where.not(id: ids_to_exclude)
  end
end

# == Schema Information
#
# Table name: web_hook_event_types
#
#  id    :integer          not null, primary key
#  name  :string           not null
#  group :integer
#
