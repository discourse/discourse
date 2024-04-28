# frozen_string_literal: true

module Chat
  class ThreadPreviewSerializer < ApplicationSerializer
    attributes :last_reply_created_at,
               :last_reply_excerpt,
               :last_reply_id,
               :participant_count,
               :reply_count
    has_many :participant_users, serializer: ::BasicUserSerializer, embed: :objects
    has_one :last_reply_user, serializer: ::BasicUserSerializer, embed: :objects

    def initialize(object, opts)
      super(object, opts)
      @participants = opts[:participants]
    end

    def reply_count
      object.replies_count_cache || 0
    end

    def last_reply_created_at
      object.last_message.created_at.iso8601
    end

    def last_reply_id
      object.last_message.id
    end

    def last_reply_excerpt
      object.last_message.excerpt || object.last_message.build_excerpt
    end

    def last_reply_user
      object.last_message.user || Chat::NullUser.new
    end

    def include_participant_data?
      @participants.present?
    end

    def include_participant_users?
      include_participant_data?
    end

    def include_participant_count?
      include_participant_data?
    end

    def participant_users
      @participant_users ||= @participants[:users].map { |user| User.new(user) }
    end

    def participant_count
      @participants[:total_count]
    end
  end
end
