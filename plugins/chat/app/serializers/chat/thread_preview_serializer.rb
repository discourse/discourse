# frozen_string_literal: true

module Chat
  class ThreadPreviewSerializer < ApplicationSerializer
    attributes :last_reply_created_at, :last_reply_excerpt, :last_reply_id

    def last_reply_created_at
      object.last_reply.created_at
    end

    def last_reply_id
      object.last_reply.id
    end

    def last_reply_excerpt
      object.last_reply.censored_excerpt
    end
  end
end
