# frozen_string_literal: true

module Chat
  class ThreadLastReplySerializer < ApplicationSerializer
    attributes :created_at, :excerpt, :id

    def excerpt
      object.censored_excerpt
    end
  end
end
