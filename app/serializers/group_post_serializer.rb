class GroupPostSerializer < ApplicationSerializer
  attributes :id,
             :cooked,
             :created_at,
             :title,
             :url,
             :user_title,
             :user_long_name

  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def title
    object.topic.title
  end

  def user_long_name
    object.user.try(:name)
  end

  def user_title
    object.user.try(:title)
  end

  def include_user_long_name?
    SiteSetting.enable_names?
  end
end

