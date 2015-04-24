class DetailedUserBadgeSerializer < BasicUserBadgeSerializer
  has_one :granted_by

  attributes :post_number, :topic_id, :topic_title

  def include_post_number?
    object.post
  end

  alias :include_topic_id? :include_post_number?
  alias :include_topic_title? :include_post_number?


  def post_number
    object.post.post_number if object.post
  end

  def topic_id
    object.post.topic_id if object.post
  end

  def topic_title
    object.post.topic.title if object.post && object.post.topic
  end

end
