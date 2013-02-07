class TopicPostCountSerializer < BasicUserSerializer

  attributes :post_count

  def id
    object[:user].id
  end

  def username
    object[:user].username
  end

  def avatar_template
    object[:user].avatar_template
  end

  def post_count
    object[:post_count]
  end


end
