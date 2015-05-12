class NotificationSerializer < ApplicationSerializer

  attributes :id,
             :notification_type,
             :read,
             :created_at,
             :post_number,
             :topic_id,
             :slug,
             :data,
             :is_warning

  def slug
    Slug.for(object.topic.title) if object.topic.present?
  end

  def is_warning
    object.topic.present? && object.topic.subtype == TopicSubtype.moderator_warning
  end

  def include_is_warning?
    is_warning
  end

  def data
    object.data_hash
  end

end
