module TopicsHelper

  def render_topic_title(topic)
    link_to(topic.title,topic.relative_url)
  end

  def render_topic_next_page_link(topic, next_page)
    link_to("next page", topic.relative_url + "?page=" + next_page )
  end
end
