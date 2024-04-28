# frozen_string_literal: true

module Chat
  class ThreadOriginalMessageSerializer < ::ApplicationSerializer
    attributes :id,
               :message,
               :cooked,
               :created_at,
               :excerpt,
               :chat_channel_id,
               :deleted_at,
               :mentioned_users,
               :user

    def excerpt
      object.excerpt || object.build_excerpt
    end

    def mentioned_users
      object
        .user_mentions
        .includes(user: :user_option)
        .limit(SiteSetting.max_mentions_per_chat_message)
        .map(&:user)
        .compact
        .sort_by(&:id)
        .map { |user| BasicUserSerializer.new(user, root: false, include_status: true) }
        .as_json
    end

    def user
      BasicUserSerializer.new(object.user, root: false, include_status: true).as_json
    end
  end
end
