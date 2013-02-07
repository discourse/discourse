class NotificationSerializer < ApplicationSerializer

  attributes :notification_type,
             :read,
             :created_at,
             :post_number,
             :topic_id,
             :slug,
             :data

  def slug
    Slug.for(object.topic.title) if object.topic.present?
  end

  def data
    object.data_hash
  end

end
