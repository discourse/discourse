require_dependency 'excerpt_type'

class PostExcerptSerializer < ActiveModel::Serializer
  include ExcerptType

  attributes :topic_id, :muted, :excerpt, :username, :created_at, :has_multiple_posts, :last_post_url, :first_post_url, :avatar_template

  def muted
    object.topic.muted?(scope.current_user)
  end

  def avatar_template
    object.user.avatar_template
  end

  def has_multiple_posts
    (object.topic.posts_count > 1)
  end

  def last_post_url
    object.topic.last_post_url
  end

  def first_post_url
    object.topic.relative_url
  end

  def include_last_post_url?
    object.post_number == 1
  end

  def include_first_post_url?
    object.post_number > 1
  end


end
