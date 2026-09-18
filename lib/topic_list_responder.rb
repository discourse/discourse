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
      format.md do
        localize_topic_list_content(list)
        title =
          if defined?(@target_user) && @target_user
            "@#{@target_user.username} - Activity"
          elsif defined?(@category) && @category
            filter = action_name.sub("category_none_", "").sub("category_", "")
            filter = @category.default_view.presence || "latest" if filter == "default"
            "#{@category.name} - #{filter.titleize}"
          elsif defined?(@tag_name) && @tag_name
            filter = action_name == "show" ? "latest" : action_name.delete_prefix("show_")
            "##{@tag_name} - #{filter.titleize}"
          else
            action_name.titleize
          end
        render_markdown(
          MarkdownEndpoint::TopicListRenderer.new(
            topics: list.topics,
            title: title,
            url: markdown_alternate_url,
            page: params[:page],
          ).render,
        )
      end
    end
  end

  private

  def localize_topic_list_content(list)
    return if list.topics.blank? || !SiteSetting.content_localization_enabled
    crawl_locale = I18n.locale

    list.topics.each do |topic|
      if ContentLocalization.show_translated_topic?(topic, guardian)
        LocalizationAttributesReplacer.replace_topic_attributes(topic, crawl_locale)
      end
    end
  end
end
