class TopicPostCountSerializer < BasicUserSerializer

  attributes :post_count, :primary_group_name,
             :primary_group_flair_url, :primary_group_flair_color, :primary_group_flair_bg_color

  def id
    object[:user].id
  end

  def username
    object[:user].username
  end

  def post_count
    object[:post_count]
  end

  def primary_group_name
    return nil unless object[:user].primary_group_id
    object[:user]&.primary_group&.name
  end

  def primary_group_flair_url
    object[:user]&.primary_group&.flair_url
  end

  def primary_group_flair_bg_color
    object[:user]&.primary_group&.flair_bg_color
  end

  def primary_group_flair_color
    object[:user]&.primary_group&.flair_color
  end

end
