# frozen_string_literal: true

module SuggestedTopicsMixin
  def self.included(klass)
    klass.attributes :related_messages
    klass.attributes :suggested_topics
    klass.attributes :suggested_group_name
  end

  def include_related_messages?
    object.related_messages&.topics
  end

  def include_suggested_topics?
    object.suggested_topics&.topics
  end

  def include_suggested_group_name?
    return false unless include_suggested_topics?
    object.topic.private_message? && scope.user
  end

  def suggested_group_name
    return if object.topic.topic_allowed_users.exists?(user_id: scope.user.id)

    if object.topic_allowed_group_ids.present?
      Group
        .joins(:group_users)
        .where(
          "group_users.group_id IN (?) AND group_users.user_id = ?",
          object.topic_allowed_group_ids,
          scope.user.id,
        )
        .pick(:name)
    end
  end

  def related_messages
    object.related_messages.topics.map do |t|
      SuggestedTopicSerializer.new(t, scope: scope, root: false)
    end
  end

  def suggested_topics
    object.suggested_topics.topics.map do |t|
      SuggestedTopicSerializer.new(t, scope: scope, root: false)
    end
  end
end
