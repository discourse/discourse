# frozen_string_literal: true

module Chat
  class Thread < ActiveRecord::Base
    EXCERPT_LENGTH = 150

    self.table_name = "chat_threads"

    belongs_to :channel, foreign_key: "channel_id", class_name: "Chat::Channel"
    belongs_to :original_message_user, foreign_key: "original_message_user_id", class_name: "User"
    belongs_to :original_message, foreign_key: "original_message_id", class_name: "Chat::Message"

    has_many :chat_messages,
             -> {
               where("deleted_at IS NULL").order(
                 "chat_messages.created_at ASC, chat_messages.id ASC",
               )
             },
             foreign_key: :thread_id,
             primary_key: :id,
             class_name: "Chat::Message"

    enum :status, { open: 0, read_only: 1, closed: 2, archived: 3 }, scopes: false

    def replies
      self.chat_messages.where.not(id: self.original_message_id)
    end

    def replies_count_cache_updated_at_redis_key
      "chat_thread:replies_count_cache_updated_at:#{self.id}"
    end

    def replies_count_cache_redis_key
      "chat_thread:replies_count_cache:#{self.id}"
    end

    def replies_count_cache_recently_updated?
      replies_count_cache_updated_at.after?(5.minutes.ago)
    end

    def replies_count_cache_updated_at
      Time.at(
        Discourse.redis.get(self.replies_count_cache_updated_at_redis_key).to_i,
        in: Time.zone,
      )
    end

    def replies_count_cache
      redis_cache = Discourse.redis.get(replies_count_cache_redis_key)&.to_i
      if redis_cache.present? && redis_cache != self.replies_count
        redis_cache
      else
        self.replies_count
      end
    end

    def set_replies_count_cache(value, update_db: false)
      self.update!(replies_count: value) if update_db
      Discourse.redis.setex(self.replies_count_cache_redis_key, 5.minutes.from_now.to_i, value)
      Jobs.enqueue_in(3.seconds, Jobs::Chat::UpdateThreadReplyCount, thread_id: self.id)
      ::Chat::Publisher.publish_thread_original_message_metadata!(self)
    end

    def increment_replies_count_cache
      self.set_replies_count_cache(self.replies_count_cache + 1)
    end

    def decrement_replies_count_cache
      self.set_replies_count_cache(self.replies_count_cache - 1)
    end

    def clear_caches!
      Discourse.redis.del(self.replies_count_cache_redis_key)
      Discourse.redis.del(self.replies_count_cache_updated_at_redis_key)
    end

    def url
      "#{channel.url}/t/#{self.id}"
    end

    def relative_url
      "#{channel.relative_url}/t/#{self.id}"
    end

    def excerpt
      original_message.excerpt(max_length: EXCERPT_LENGTH)
    end

    def self.ensure_consistency!
      update_counts
    end

    def self.update_counts
      # NOTE: Chat::Thread#replies_count is not updated every time
      # a message is created or deleted in a channel, the UI will lag
      # behind unless it is kept in sync with MessageBus. The count
      # has 1 subtracted from it to account for the original message.
      #
      # It is updated eventually via Jobs::Chat::PeriodicalUpdates. In
      # future we may want to update this more frequently.
      DB.exec <<~SQL
        UPDATE chat_threads threads
        SET replies_count = subquery.replies_count
        FROM (
          SELECT COUNT(*) - 1 AS replies_count, thread_id
          FROM chat_messages
          WHERE chat_messages.deleted_at IS NULL AND thread_id IS NOT NULL
          GROUP BY thread_id
        ) subquery
        WHERE threads.id = subquery.thread_id
        AND subquery.replies_count != threads.replies_count
      SQL
      Discourse.redis.delete_prefixed("chat_thread:replies_count_cache")
    end
  end
end

# == Schema Information
#
# Table name: chat_threads
#
#  id                       :bigint           not null, primary key
#  channel_id               :integer          not null
#  original_message_id      :integer          not null
#  original_message_user_id :integer          not null
#  status                   :integer          default("open"), not null
#  title                    :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  replies_count            :integer          default(0), not null
#
# Indexes
#
#  index_chat_threads_on_channel_id                (channel_id)
#  index_chat_threads_on_channel_id_and_status     (channel_id,status)
#  index_chat_threads_on_original_message_id       (original_message_id)
#  index_chat_threads_on_original_message_user_id  (original_message_user_id)
#  index_chat_threads_on_replies_count             (replies_count)
#  index_chat_threads_on_status                    (status)
#
