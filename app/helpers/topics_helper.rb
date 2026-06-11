# frozen_string_literal: true

module TopicsHelper
  include ApplicationHelper

  def topic_path_with_flat_param(path, force: nil, anchor: nil)
    force = params[:flat] == "1" if force.nil?
    path = path.to_s

    if force && !path.match?(/[?&]flat=1(?:&|$)/)
      path += path.include?("?") ? "&flat=1" : "?flat=1"
    end

    anchor.present? ? "#{path}##{anchor}" : path
  end

  def nested_posts_have_unrendered_replies?(posts)
    Array(posts).any? { |post| nested_post_has_unrendered_replies?(post) }
  end

  def nested_post_has_unrendered_replies?(post)
    children = Array(post[:children])

    post[:direct_reply_count].to_i > children.length || nested_posts_have_unrendered_replies?(children)
  end

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
    return if cookies.key?(ContentLocalization::SHOW_ORIGINAL_COOKIE)
    return if current_user&.user_option&.show_original_content

    # locale param is appropriately set in the application controller
    # depending on site settings and presence of user
    locale = I18n.locale

    LocalizationAttributesReplacer.replace_topic_attributes(topic_view.topic, locale)
    topic_view.posts.each do |post|
      LocalizationAttributesReplacer.replace_post_attributes(post, locale)
    end
  end
end
