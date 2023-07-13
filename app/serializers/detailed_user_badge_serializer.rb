# frozen_string_literal: true

class DetailedUserBadgeSerializer < BasicUserBadgeSerializer
  include UserBadgePostAndTopicAttributesMixin

  has_one :granted_by, serializer: UserBadgeSerializer::UserSerializer

  attributes :post_number, :topic_id, :topic_title, :is_favorite, :can_favorite

  def post_number
    object.post.post_number
  end

  def include_post_number?
    include_post_attributes?
  end

  def topic_id
    object.post.topic_id
  end

  def include_topic_id?
    include_topic_attributes?
  end

  def topic_title
    object.post.topic.title
  end

  def include_topic_title?
    include_topic_id?
  end

  def can_favorite
    SiteSetting.max_favorite_badges > 0 &&
      (scope.current_user.present? && object.user_id == scope.current_user.id) &&
      !(1..4).include?(object.badge_id)
  end
end
