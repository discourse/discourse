# frozen_string_literal: true

module DiscourseChatIntegration
  class ChatIntegrationReferencePost
    def initialize(user:, topic:, kind:, raw: nil, context: {})
      @user = user
      @topic = topic
      @kind = kind
      @raw = raw if raw.present?
      @context = context
      @created_at = Time.current
    end

    def id
      @topic.posts.empty? ? @topic.id : @topic.posts.first.id
    end

    def user
      @user
    end

    def topic
      @topic
    end

    def full_url
      @topic.posts.empty? ? @topic.url : @topic.posts.first.full_url
    end

    def excerpt(maxlength = nil, options = {})
      cooked = PrettyText.cook(raw, { user_id: user.id })
      maxlength ||= SiteSetting.post_excerpt_maxlength
      PrettyText.excerpt(cooked, maxlength, options)
    end

    def is_first_post?
      topic.try(:highest_post_number) == 0
    end

    def created_at
      @created_at
    end

    def raw
      if @raw.nil? && @kind == DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED
        tag_list_to_raw = ->(tag_list) do
          tag_list.sort.map { |tag_name| "##{tag_name}" }.join(", ")
        end

        added_tags = @context["added_tags"]
        removed_tags = @context["removed_tags"]

        @raw =
          if added_tags.present? && removed_tags.present?
            I18n.t(
              "chat_integration.topic_tag_changed.added_and_removed",
              added: tag_list_to_raw.call(added_tags),
              removed: tag_list_to_raw.call(removed_tags),
            )
          elsif added_tags.present?
            I18n.t(
              "chat_integration.topic_tag_changed.added",
              added: tag_list_to_raw.call(added_tags),
            )
          elsif removed_tags.present?
            I18n.t(
              "chat_integration.topic_tag_changed.removed",
              removed: tag_list_to_raw.call(removed_tags),
            )
          end
      end
      @raw
    end
  end
end
