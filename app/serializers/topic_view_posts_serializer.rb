class TopicViewPostsSerializer < ApplicationSerializer
  include PostStreamSerializerMixin

  attributes :id

  def id
    object.topic.id
  end

end
