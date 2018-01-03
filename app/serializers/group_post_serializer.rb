require_relative 'post_item_excerpt'

class GroupPostSerializer < ApplicationSerializer
  include PostItemExcerpt

  attributes :id,
             :created_at,
             :title,
             :url,
             :category_id,
             :post_number,
             :topic_id

  has_one :user, serializer: GroupPostUserSerializer, embed: :object
  has_one :topic, serializer: BasicTopicSerializer, embed: :object

  def title
    object.topic.title
  end

  def include_user_long_name?
    SiteSetting.enable_names?
  end

  def category_id
    object.topic.category_id
  end
end
