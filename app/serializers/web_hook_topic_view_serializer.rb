require_dependency 'pinned_check'

class WebHookTopicViewSerializer < TopicViewSerializer
  def include_post_stream?
    false
  end

  def include_timeline_lookup?
    false
  end
end
