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
    return if cookies.key?(ContentLocalization::SHOW_ORIGINAL_COOKIE)
    return if current_user&.user_option&.show_original_content
    crawl_locale = I18n.locale

    list.topics.each do |topic|
      LocalizationAttributesReplacer.replace_topic_attributes(topic, crawl_locale)
    end
  end
end
