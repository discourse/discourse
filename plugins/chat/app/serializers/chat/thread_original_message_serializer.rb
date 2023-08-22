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
               :mentioned_users

    def excerpt
      object.censored_excerpt
    end

    def mentioned_users
      object
        .chat_mentions
        .map(&:user)
        .compact
        .sort_by(&:id)
        .map { |user| BasicUserWithStatusSerializer.new(user, root: false) }
        .as_json
    end

    has_one :user, serializer: BasicUserWithStatusSerializer, embed: :objects
  end
end
