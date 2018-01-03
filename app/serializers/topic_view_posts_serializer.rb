class TopicViewPostsSerializer < ApplicationSerializer
  include PostStreamSerializerMixin
  include SuggestedTopicsMixin

  attributes :id

  def id
    object.topic.id
  end

end
