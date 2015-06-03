module TopicsHelper

  def render_topic_title(topic)
    link_to(topic.title,topic.relative_url)
  end

  def categories_breadcrumb(topic)
    breadcrumb = []

    category = topic.category
    if category && !category.uncategorized?
      if (parent = category.parent_category)
        breadcrumb.push url: parent.url, name: parent.name
      end
      breadcrumb.push url: category.url, name: category.name
    end
    breadcrumb
  end

end
