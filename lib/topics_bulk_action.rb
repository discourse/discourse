class TopicsBulkAction

  def initialize(user, topic_ids, operation)
    @user = user
    @topic_ids = topic_ids
    @operation = operation
  end

  def perform!
    []
  end

end

