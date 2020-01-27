# frozen_string_literal: true

module TopicsHelper
  include ApplicationHelper

  def render_topic_title(topic)
    link_to(Emoji.gsub_emoji_to_unicode(topic.title), topic.relative_url)
  end

  def categories_breadcrumb(topic)
    breadcrumb = []
    category = topic.category

    if category && !category.uncategorized?
      breadcrumb.push(url: category.url, name: category.name)
      while category = category.parent_category
        breadcrumb.prepend(url: category.url, name: category.name)
      end
    end

    Plugin::Filter.apply(:topic_categories_breadcrumb, topic, breadcrumb)
  end

end
