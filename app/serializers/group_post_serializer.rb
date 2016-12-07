class GroupPostSerializer < ApplicationSerializer
  attributes :id,
             :excerpt,
             :created_at,
             :title,
             :url,
             :category

  has_one :user, serializer: GroupPostUserSerializer, embed: :object
  has_one :topic, serializer: BasicTopicSerializer, embed: :object

  def title
    object.topic.title
  end

  def include_user_long_name?
    SiteSetting.enable_names?
  end

  def category
    object.topic.category
  end
end
