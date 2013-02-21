module TopicsHelper

  def render_topic_title(topic)
    link_to(topic.title,topic.relative_url)
  end

  def render_topic_posts_count(topic)
    content_tag(:span, "[#{topic.posts_count}]", :class => "posts" )
  end
end
