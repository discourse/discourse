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

    list.topics.each do |topic|
      LocalizationAttributesReplacer.replace_topic_attributes(topic, crawl_locale)
    end
  end
end
