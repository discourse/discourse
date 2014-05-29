class PostActionUserSerializer < BasicUserSerializer
  attributes :post_url

  def id
    object.user.id
  end

  def username
    object.user.username
  end

  def uploaded_avatar_id
    object.user.uploaded_avatar_id
  end

  def avatar_template
    object.user.avatar_template
  end

  def post_url
    object.related_post.url if object.related_post_id && object.related_post
  end

end
