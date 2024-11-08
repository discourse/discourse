# frozen_string_literal: true

module Chat
  class Thread < ActiveRecord::Base
    MAX_TITLE_LENGTH = 100

    include Chat::ThreadCache
    include HasCustomFields

    self.table_name = "chat_threads"

    belongs_to :channel, foreign_key: "channel_id", class_name: "Chat::Channel"
    belongs_to :original_message_user, foreign_key: "original_message_user_id", class_name: "User"
    belongs_to :original_message,
               -> { with_deleted },
               foreign_key: "original_message_id",
               class_name: "Chat::Message"

    has_many :chat_messages,
             -> do
               where("deleted_at IS NULL").order(
                 "chat_messages.created_at ASC, chat_messages.id ASC",
               )
             end,
             foreign_key: :thread_id,
             primary_key: :id,
             class_name: "Chat::Message"
    has_many :user_chat_thread_memberships
    belongs_to :last_message,
               class_name: "Chat::Message",
               foreign_key: :last_message_id,
               optional: true
    def last_message
      super || NullMessage.new
    end

    enum :status, { open: 0, read_only: 1, closed: 2, archived: 3 }, scopes: false

    validates :title, length: { maximum: Chat::Thread::MAX_TITLE_LENGTH }

    # Since the `replies` for the thread can all be deleted, to avoid errors
    # in lists and previews of the thread, we can consider the original message
    # as the last message in this case as a fallback.
    before_create { self.last_message_id = self.original_message_id }

    def add(user, notification_level: Chat::NotificationLevels.all[:tracking])
      membership = Chat::UserChatThreadMembership.find_by(user: user, thread: self)
      return membership if membership

      Chat::UserChatThreadMembership.create!(
        user: user,
        thread: self,
        notification_level: notification_level,
      )
    end

    def remove(user)
      Chat::UserChatThreadMembership.find_by(user: user, thread: self)&.destroy
    end

    def membership_for(user)
      user_chat_thread_memberships.find_by(user: user)
    end

    def replies
      self.chat_messages.where.not(id: self.original_message_id).order("created_at ASC, id ASC")
    end

    def url
      "#{channel.url}/t/#{self.id}"
    end

    def relative_url
      "#{channel.relative_url}/t/#{self.id}"
    end

    def excerpt
      original_message.excerpt
    end

    def update_last_message_id!
      self.update!(last_message_id: self.latest_not_deleted_message_id)
    end

    def latest_not_deleted_message_id(anchor_message_id: nil)
      DB.query_single(
        <<~SQL,
        SELECT id FROM chat_messages
        WHERE chat_channel_id = :channel_id
        AND thread_id = :thread_id
        AND deleted_at IS NULL
        #{anchor_message_id ? "AND id < :anchor_message_id" : ""}
        ORDER BY created_at DESC, id DESC
        LIMIT 1
      SQL
        channel_id: self.channel_id,
        thread_id: self.id,
        anchor_message_id: anchor_message_id,
      ).first
    end

    def self.grouped_messages(thread_ids: nil, message_ids: nil, include_original_message: true)
      DB.query(<<~SQL, message_ids: message_ids, thread_ids: thread_ids)
        SELECT thread_id,
          array_agg(chat_messages.id ORDER BY chat_messages.created_at, chat_messages.id) AS thread_message_ids,
          chat_threads.original_message_id
        FROM chat_messages
        INNER JOIN chat_threads ON chat_threads.id = chat_messages.thread_id
        WHERE thread_id IS NOT NULL
        #{thread_ids ? "AND thread_id IN (:thread_ids)" : ""}
        #{message_ids ? "AND chat_messages.id IN (:message_ids)" : ""}
        #{include_original_message ? "" : "AND chat_messages.id != chat_threads.original_message_id"}
        GROUP BY thread_id, chat_threads.original_message_id;
      SQL
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
      updated_thread_ids = DB.query_single <<~SQL
        UPDATE chat_threads ct
        SET replies_count = GREATEST(COALESCE(subquery.new_count, 0), 0)
        FROM (
          SELECT cm.thread_id, COUNT(cm.*) - 1 AS new_count
          FROM chat_threads
          LEFT JOIN chat_messages cm ON cm.thread_id = chat_threads.id AND cm.deleted_at IS NULL
          GROUP BY cm.thread_id
        ) AS subquery
        WHERE ct.id = subquery.thread_id AND ct.replies_count IS DISTINCT FROM GREATEST(COALESCE(subquery.new_count, 0), 0)
        RETURNING ct.id AS thread_id
      SQL
      return if updated_thread_ids.empty?
      self.clear_caches!(updated_thread_ids)
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
#  last_message_id          :bigint
#
# Indexes
#
#  index_chat_threads_on_channel_id                (channel_id)
#  index_chat_threads_on_channel_id_and_status     (channel_id,status)
#  index_chat_threads_on_last_message_id           (last_message_id)
#  index_chat_threads_on_original_message_id       (original_message_id)
#  index_chat_threads_on_original_message_user_id  (original_message_user_id)
#  index_chat_threads_on_replies_count             (replies_count)
#  index_chat_threads_on_status                    (status)
#
