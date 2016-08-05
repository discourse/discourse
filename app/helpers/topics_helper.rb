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

    if (tags = topic.tags).present?
      tags.each do |tag|
        url = "#{Discourse.base_url}/tags/#{tag.name}"
        breadcrumb << {url: url, name: tag.name}
      end
    end

    Plugin::Filter.apply(:topic_categories_breadcrumb, topic, breadcrumb)
  end

end
