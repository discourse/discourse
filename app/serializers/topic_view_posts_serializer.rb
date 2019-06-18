# frozen_string_literal: true

class TopicViewPostsSerializer < ApplicationSerializer
  include PostStreamSerializerMixin
  include SuggestedTopicsMixin

  attributes :id

  def id
    object.topic.id
  end

  def include_stream?
    false
  end

  def include_gaps?
    false
  end

  def include_timeline_lookup?
    false
  end

end
