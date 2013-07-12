require_dependency 'pinned_check'

class TopicViewSerializer < ApplicationSerializer
  include PostStreamSerializerMixin

  # These attributes will be delegated to the topic
  def self.topic_attributes
    [:id,
     :title,
     :fancy_title,
     :posts_count,
     :created_at,
     :views,
     :reply_count,
     :last_posted_at,
     :visible,
     :closed,
     :archived,
     :has_best_of,
     :archetype,
     :slug,
     :category_id,
     :deleted_at]
  end

  attributes :draft,
             :draft_key,
             :draft_sequence,
             :starred,
             :posted,
             :pinned,
             :details,
             :highest_post_number,
             :last_read_post_number,
             :deleted_by

  # Define a delegator for each attribute of the topic we want
  attributes *topic_attributes
  topic_attributes.each do |ta|
    class_eval %{def #{ta}
      object.topic.#{ta}
    end}
  end

  # TODO: Split off into proper object / serializer
  def details
    result = {
      auto_close_at: object.topic.auto_close_at,
      created_by: BasicUserSerializer.new(object.topic.user, scope: scope, root: false),
      last_poster: BasicUserSerializer.new(object.topic.last_poster, scope: scope, root: false)
    }

    if object.topic.allowed_users.present?
      result[:allowed_users] = object.topic.allowed_users.map do |user|
        BasicUserSerializer.new(user, scope: scope, root: false)
      end
    end

    if object.topic.allowed_groups.present?
      result[:allowed_groups] = object.topic.allowed_groups.map do |ag|
        BasicGroupSerializer.new(ag, scope: scope, root: false)
      end
    end

    if object.post_counts_by_user.present?
      result[:participants] = object.post_counts_by_user.map do |pc|
        TopicPostCountSerializer.new({user: object.participants[pc[0]], post_count: pc[1]}, scope: scope, root: false)
      end
    end


    if object.suggested_topics.try(:topics).present?
      result[:suggested_topics] = object.suggested_topics.topics.map do |user|
        SuggestedTopicSerializer.new(user, scope: scope, root: false)
      end
    end

    if object.links.present?
      result[:links] = object.links.map do |user|
        TopicLinkSerializer.new(user, scope: scope, root: false)
      end
    end

    if has_topic_user?
      result[:notification_level] = object.topic_user.notification_level
      result[:notifications_reason_id] = object.topic_user.notifications_reason_id
    end

    result[:can_move_posts] = true if scope.can_move_posts?(object.topic)
    result[:can_edit] = true if scope.can_edit?(object.topic)
    result[:can_delete] = true if scope.can_delete?(object.topic)
    result[:can_recover] = true if scope.can_recover_topic?(object.topic)
    result[:can_remove_allowed_users] = true if scope.can_remove_allowed_users?(object.topic)
    result[:can_invite_to] = true if scope.can_invite_to?(object.topic)
    result[:can_create_post] = true if scope.can_create?(Post, object.topic)
    result[:can_reply_as_new_topic] = true if scope.can_reply_as_new_topic?(object.topic)
    result
  end

  def draft
    object.draft
  end

  def draft_key
    object.draft_key
  end

  def draft_sequence
    object.draft_sequence
  end

  def deleted_by
    BasicUserSerializer.new(object.topic.deleted_by, root: false).as_json
  end

  # Topic user stuff
  def has_topic_user?
    object.topic_user.present?
  end

  def starred
    object.topic_user.starred?
  end
  alias_method :include_starred?, :has_topic_user?

  def highest_post_number
    object.highest_post_number
  end

  def last_read_post_number
    object.topic_user.last_read_post_number
  end
  alias_method :include_last_read_post_number?, :has_topic_user?

  def posted
    object.topic_user.posted?
  end
  alias_method :include_posted?, :has_topic_user?

  def pinned
    PinnedCheck.new(object.topic, object.topic_user).pinned?
  end


end
