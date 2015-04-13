module TopicsHelper

  def render_topic_title(topic)
    link_to(topic.title,topic.relative_url)
  end

  def categories_breadcrumb(topic)
    breadcrumb = [{url: categories_path,
                   name: I18n.t('js.filters.categories.title')}]

    category = topic.category
    if category
      if (parent = category.parent_category)
        breadcrumb.push url: parent.url, name: parent.name
      end
      breadcrumb.push url: category.url, name: category.name
    end
    breadcrumb
  end

end
