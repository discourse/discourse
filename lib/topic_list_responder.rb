# frozen_string_literal: true

module TopicListResponder
  def respond_with_list(list)
    discourse_expires_in 1.minute

    respond_to do |format|
      format.html do
        @list = list
        localize_topic_list_content(list)

        store_preloaded(
          list.preload_key,
          MultiJson.dump(TopicListSerializer.new(list, scope: guardian)),
        )
        render "list/list"
      end
      format.json { render_serialized(list, TopicListSerializer) }
    end
  end

  private

  def localize_topic_list_content(list)
    return if list.topics.blank? || !SiteSetting.content_localization_enabled
    crawl_locale = params[Discourse::LOCALE_PARAM].presence || SiteSetting.default_locale

    list.topics.each { |topic| replace_topic_attributes(crawl_locale, topic) }
  end

  def replace_topic_attributes(crawl_locale, topic)
    if topic.locale.present? && !LocaleNormalizer.is_same?(topic.locale, crawl_locale) &&
         (loc = topic.get_localization(crawl_locale))
      topic.fancy_title = loc.fancy_title if loc.fancy_title.present?
      topic.excerpt = loc.excerpt if loc.excerpt.present?

      category = topic.category
      replace_category_name(category, crawl_locale)
    end
  end

  def replace_category_name(category, crawl_locale)
    if category.locale.present? && !LocaleNormalizer.is_same?(category.locale, crawl_locale) &&
         (category_loc = category.get_localization(crawl_locale))
      category.name = category_loc.name if category_loc.name.present?
    end
  end
end
