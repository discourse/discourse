# frozen_string_literal: true

module Jobs
  module Chat
    class UpdateThreadReplyCount < Jobs::Base
      def execute(args = {})
        thread = ::Chat::Thread.find_by(id: args[:thread_id])
        return if thread.blank?
        return if thread.replies_count_cache_recently_updated?

        Discourse.redis.setex(
          ::Chat::Thread.replies_count_cache_updated_at_redis_key(thread.id),
          5.minutes.from_now.to_i,
          Time.zone.now.to_i,
        )
        thread.set_replies_count_cache(thread.replies.count, update_db: true)

        ::Chat::Publisher.publish_thread_original_message_metadata!(thread)
      end
    end
  end
end
