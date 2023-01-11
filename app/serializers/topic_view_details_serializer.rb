# frozen_string_literal: true

class TopicViewDetailsSerializer < ApplicationSerializer
  def self.can_attributes
    %i[
      can_move_posts
      can_delete
      can_permanently_delete
      can_recover
      can_remove_allowed_users
      can_invite_to
      can_invite_via_email
      can_create_post
      can_reply_as_new_topic
      can_flag_topic
      can_convert_topic
      can_review_topic
      can_edit_tags
      can_publish_page
      can_close_topic
      can_archive_topic
      can_split_merge_topic
      can_edit_staff_notes
      can_toggle_topic_visibility
      can_pin_unpin_topic
      can_moderate_category
    ]
  end

  # NOTE: `can_edit` is defined as an attribute because we explicitly want
  # it returned even if it has a value of `false`
  attributes(
    :can_edit,
    :notification_level,
    :notifications_reason_id,
    *can_attributes,
    :can_remove_self_id,
    :participants,
    :allowed_users,
  )

  has_one :created_by, serializer: BasicUserSerializer, embed: :objects
  has_one :last_poster, serializer: BasicUserSerializer, embed: :objects
  has_many :links, serializer: TopicLinkSerializer, embed: :objects
  has_many :participants, serializer: TopicPostCountSerializer, embed: :objects
  has_many :allowed_users, serializer: BasicUserSerializer, embed: :objects
  has_many :allowed_groups, serializer: BasicGroupSerializer, embed: :objects

  def participants
    object
      .post_counts_by_user
      .reject { |p| object.participants[p].blank? }
      .map { |pc| { user: object.participants[pc[0]], post_count: pc[1] } }
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

  can_attributes.each { |ca| define_method(ca) { true } }

  # NOTE: A Category Group Moderator moving a topic to a different category
  # may result in the 'can_edit?' result changing from `true` to `false`.
  # Explicitly returning a `false` value is required to update the client UI.
  def can_edit
    scope.can_edit?(object.topic)
  end

  def include_can_review_topic?
    scope.can_review_topic?(object.topic)
  end

  def include_can_move_posts?
    scope.can_move_posts?(object.topic)
  end

  def include_can_delete?
    scope.can_delete?(object.topic)
  end

  def include_can_permanently_delete?
    SiteSetting.can_permanently_delete && scope.is_admin? && object.topic.deleted_at
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

  def include_can_toggle_topic_visibility?
    scope.can_toggle_topic_visibility?(object.topic)
  end

  def include_can_pin_unpin_topic?
    scope.can_pin_unpin_topic?(object.topic)
  end

  def can_perform_action_available_to_group_moderators?
    @can_perform_action_available_to_group_moderators ||=
      scope.can_perform_action_available_to_group_moderators?(object.topic)
  end
  alias include_can_close_topic? can_perform_action_available_to_group_moderators?
  alias include_can_archive_topic? can_perform_action_available_to_group_moderators?
  alias include_can_split_merge_topic? can_perform_action_available_to_group_moderators?
  alias include_can_edit_staff_notes? can_perform_action_available_to_group_moderators?
  alias include_can_moderate_category? can_perform_action_available_to_group_moderators?

  def include_can_publish_page?
    scope.can_publish_page?(object.topic)
  end

  def allowed_users
    object.topic.allowed_users.reject do |user|
      object.group_allowed_user_ids.include?(user.id) && user != scope.user
    end
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
