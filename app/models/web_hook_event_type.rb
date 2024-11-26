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
         custom: 16,
       },
       _scopes: false

  TYPES = {
    topic_created: 101,
    topic_revised: 102,
    topic_edited: 103,
    topic_destroyed: 104,
    topic_recovered: 105,
    post_created: 201,
    post_edited: 202,
    post_destroyed: 203,
    post_recovered: 204,
    user_logged_in: 301,
    user_logged_out: 302,
    user_confirmed_email: 303,
    user_created: 304,
    user_approved: 305,
    user_updated: 306,
    user_destroyed: 307,
    user_suspended: 308,
    user_unsuspended: 309,
    group_created: 401,
    group_updated: 402,
    group_destroyed: 403,
    category_created: 501,
    category_updated: 502,
    category_destroyed: 503,
    tag_created: 601,
    tag_updated: 602,
    tag_destroyed: 603,
    reviewable_created: 901,
    reviewable_updated: 902,
    notification_created: 1001,
    solved_accepted_solution: 1101,
    solved_unaccepted_solution: 1102,
    assign_assigned: 1201,
    assign_unassigned: 1202,
    user_badge_granted: 1301,
    user_badge_revoked: 1302,
    group_user_added: 1401,
    group_user_removed: 1402,
    like_created: 1501,
    user_promoted_created: 1601,
    voting_topic_upvote: 1701,
    voting_topic_unvote: 1702,
    chat_message_created: 1801,
    chat_message_edited: 1802,
    chat_message_trashed: 1803,
    chat_message_restored: 1804,
  }

  has_and_belongs_to_many :web_hooks

  default_scope { order("id ASC") }

  validates :name, presence: true, uniqueness: true

  scope :active_grouped, -> { active.where.not(group: nil).group_by(&:group) }

  def self.active
    ids_to_exclude = []
    unless defined?(SiteSetting.solved_enabled) && SiteSetting.solved_enabled
      ids_to_exclude.concat([TYPES[:solved_accepted_solution], TYPES[:solved_unaccepted_solution]])
    end
    unless defined?(SiteSetting.assign_enabled) && SiteSetting.assign_enabled
      ids_to_exclude.concat([TYPES[:assign_assigned], TYPES[:assign_unassigned]])
    end
    unless defined?(SiteSetting.topic_voting_enabled) && SiteSetting.topic_voting_enabled
      ids_to_exclude.concat([TYPES[:voting_topic_upvote], TYPES[:voting_topic_unvote]])
    end
    unless defined?(SiteSetting.chat_enabled) && SiteSetting.chat_enabled
      ids_to_exclude.concat(
        [
          TYPES[:chat_message_created],
          TYPES[:chat_message_edited],
          TYPES[:chat_message_trashed],
          TYPES[:chat_message_restored],
        ],
      )
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
