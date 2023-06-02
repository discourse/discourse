# frozen_string_literal: true

module Chat
  # Builds a query to find the total count of participants for one
  # or more threads (on a per-thread basis), as well as up to 3
  # participants in the thread. The participants will be made up
  # of:
  #
  # - Participant 1 & 2 - The most frequent messagers in the thread.
  # - Participant 3 - The most recent messager in the thread.
  #
  # This result should be cached to avoid unnecessary queries,
  # since the participants will not often change for a thread,
  # and if there is a delay in updating them based on message
  # count it is not a big deal.
  class ThreadParticipantQuery
    # @param thread_ids [Array<Integer>] The IDs of the threads to query.
    # @return [Hash<Integer, Hash>] A hash of thread IDs to participant data.
    def self.call(thread_ids:)
      thread_messager_stats = DB.query(<<~SQL, thread_ids: thread_ids)
        SELECT * FROM (
          SELECT chat_messages.thread_id, chat_messages.user_id, COUNT(*) AS message_count,
            ROW_NUMBER() OVER (PARTITION BY chat_messages.thread_id ORDER BY COUNT(*) DESC) AS row_number
          FROM chat_messages
          INNER JOIN chat_threads ON chat_threads.id = chat_messages.thread_id
          INNER JOIN user_chat_thread_memberships ON user_chat_thread_memberships.thread_id = chat_threads.id
            AND user_chat_thread_memberships.user_id = chat_messages.user_id
          WHERE chat_messages.thread_id IN (:thread_ids)
          AND chat_messages.deleted_at IS NULL
          GROUP BY chat_messages.thread_id, chat_messages.user_id
          ORDER BY chat_messages.thread_id ASC, message_count DESC, chat_messages.user_id ASC
        ) AS thread_messager_stats
      SQL

      most_recent_messagers = DB.query(<<~SQL, thread_ids: thread_ids)
        SELECT DISTINCT ON (thread_id) chat_messages.thread_id, chat_messages.user_id
        FROM chat_messages
        INNER JOIN chat_threads ON chat_threads.id = chat_messages.thread_id
        INNER JOIN user_chat_thread_memberships ON user_chat_thread_memberships.thread_id = chat_threads.id
          AND user_chat_thread_memberships.user_id = chat_messages.user_id
        WHERE chat_messages.thread_id IN (:thread_ids)
        AND chat_messages.deleted_at IS NULL
        ORDER BY chat_messages.thread_id ASC, chat_messages.created_at DESC
      SQL
      most_recent_messagers = most_recent_messagers.map { |mrm| [mrm.thread_id, mrm.user_id] }.to_h

      thread_participants = {}
      thread_messager_stats.each do |thread_messager_stat|
        thread_id = thread_messager_stat.thread_id
        thread_participants[thread_id] ||= {}
        thread_participants[thread_id][:user_ids] ||= []
        thread_participants[thread_id][:total_count] ||= 0

        # If we want to return more of the top N users in the thread we
        # can just increase the number here.
        if thread_participants[thread_id][:user_ids].length < 2 &&
             thread_messager_stat.user_id != most_recent_messagers[thread_id]
          thread_participants[thread_id][:user_ids].push(thread_messager_stat.user_id)
        end

        thread_participants[thread_id][:total_count] += 1
      end

      # Always put the most recent messenger at the end of the array.
      most_recent_messagers.each do |thread_id, user_id|
        thread_participants[thread_id][:user_ids].push(user_id)
      end

      thread_participants
    end
  end
end
