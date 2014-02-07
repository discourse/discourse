class GroupPostSerializer < ApplicationSerializer
  attributes :id,
             :cooked,
             :created_at,
             :title,
             :url

  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def title
    object.topic.title
  end

end

