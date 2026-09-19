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
      breadcrumb.push(url: category.url, name: category.name, color: category.color)
      while category = category.parent_category
        breadcrumb.prepend(url: category.url, name: category.name, color: category.color)
      end
    end

    Plugin::Filter.apply(:topic_categories_breadcrumb, topic, breadcrumb)
  end

  def localize_topic_view_content(topic_view)
    # locale param is appropriately set in the application controller
    # depending on site settings and presence of user
    locale = I18n.locale

    if ContentLocalization.show_translated_topic?(topic_view.topic, guardian)
      LocalizationAttributesReplacer.replace_topic_attributes(topic_view.topic, locale)
    end

    topic_view.posts.each do |post|
      if ContentLocalization.show_translated_post?(post, guardian)
        LocalizationAttributesReplacer.replace_post_attributes(post, locale)
      end
    end
  end
end
