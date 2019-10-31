# frozen_string_literal: true

class TopicViewDetailsSerializer < ApplicationSerializer

  def self.can_attributes
    [:can_move_posts,
     :can_edit,
     :can_delete,
     :can_recover,
     :can_remove_allowed_users,
     :can_invite_to,
     :can_invite_via_email,
     :can_create_post,
     :can_reply_as_new_topic,
     :can_flag_topic,
     :can_convert_topic,
     :can_review_topic,
     :can_edit_tags]
  end

  attributes(
    :notification_level,
    :notifications_reason_id,
    *can_attributes,
    :can_remove_self_id,
    :participants,
    :allowed_users
  )

  has_one :created_by, serializer: BasicUserSerializer, embed: :objects
  has_one :last_poster, serializer: BasicUserSerializer, embed: :objects
  has_many :links, serializer: TopicLinkSerializer, embed: :objects
  has_many :participants, serializer: TopicPostCountSerializer, embed: :objects
  has_many :allowed_users, serializer: BasicUserSerializer, embed: :objects
  has_many :allowed_groups, serializer: BasicGroupSerializer, embed: :objects

  def participants
    object.post_counts_by_user.reject { |p| object.participants[p].blank? }.map do |pc|
      { user: object.participants[pc[0]], post_count: pc[1] }
    end
  end

  def include_participants?
    object.post_counts_by_user.present?
  end

  def include_links?
    object.links.present?
  end

  def created_by
    object.topic.user
  end

  def last_poster
    object.topic.last_poster
  end

  def notification_level
    object.topic_user&.notification_level || TopicUser.notification_levels[:regular]
  end

  def notifications_reason_id
    object.topic_user.notifications_reason_id
  end

  def include_notifications_reason_id?
    object.topic_user.present?
  end

  # confusingly this is an id, not a bool like all other `can` methods
  def can_remove_self_id
    scope.user.id
  end

  def include_can_remove_self_id?
    scope.can_remove_allowed_users?(object.topic, scope.user)
  end

  can_attributes.each do |ca|
    define_method(ca) { true }
  end

  def include_can_review_topic?
    scope.can_review_topic?(object.topic)
  end

  def include_can_move_posts?
    scope.can_move_posts?(object.topic)
  end

  def include_can_edit?
    scope.can_edit?(object.topic)
  end

  def include_can_delete?
    scope.can_delete?(object.topic)
  end

  def include_can_recover?
    scope.can_recover_topic?(object.topic)
  end

  def include_can_remove_allowed_users?
    scope.can_remove_allowed_users?(object.topic)
  end

  def include_can_invite_to?
    scope.can_invite_to?(object.topic)
  end

  def include_can_invite_via_email?
    scope.can_invite_via_email?(object.topic)
  end

  def include_can_create_post?
    scope.can_create?(Post, object.topic)
  end

  def include_can_reply_as_new_topic?
    scope.can_reply_as_new_topic?(object.topic)
  end

  def include_can_flag_topic?
    object.actions_summary.any? { |a| a[:can_act] }
  end

  def include_can_convert_topic?
    scope.can_convert_topic?(object.topic)
  end

  def include_can_edit_tags?
    !scope.can_edit?(object.topic) && scope.can_edit_tags?(object.topic)
  end

  def allowed_users
    object.topic.allowed_users.reject { |user| object.group_allowed_user_ids.include?(user.id) }
  end

  def include_allowed_users?
    object.personal_message
  end

  def allowed_groups
    object.topic.allowed_groups
  end

  def include_allowed_groups?
    object.personal_message
  end

end
