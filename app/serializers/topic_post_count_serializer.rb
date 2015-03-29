class TopicPostCountSerializer < BasicUserSerializer

  attributes :post_count

  def id
    object[:user].id
  end

  def username
    object[:user].username
  end

  def post_count
    object[:post_count]
  end

  def uploaded_avatar_id
    object[:user].uploaded_avatar_id
  end

end
