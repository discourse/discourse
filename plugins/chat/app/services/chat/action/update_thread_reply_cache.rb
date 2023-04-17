# frozen_string_literal: true

module Chat
  module Action
    class UpdateThreadReplyCache
      def self.call!(thread)
        Jobs.enqueue_in(3.seconds, Jobs::Chat::UpdateThreadReplyCount, thread_id: thread.id)
      end
    end
  end
end
