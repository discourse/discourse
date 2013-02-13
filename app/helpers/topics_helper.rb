module TopicsHelper

  def render_topic_title(topic)
    link_to(topic.title,topic.relative_url)
  end

end
