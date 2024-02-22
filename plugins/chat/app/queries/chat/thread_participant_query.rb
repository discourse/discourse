# frozen_string_literal: true

module Chat
  # Builds a query to find the total count of participants for one
  # or more threads (on a per-thread basis), as well as up to 10
  # participants in the thread. The participants will be made up
  # of:
  #
  # The most frequent participants in the thread:
  # - Participant 1-2 (preview)
  # - Participant 1-9 (thread list)
  # The most recent participant in the thread.
  # - Participant 10
  #
  # This result should be cached to avoid unnecessary queries,
  # since the participants will not often change for a thread,
  # and if there is a delay in updating them based on message
  # count it is not a big deal.
  class ThreadParticipantQuery
    MAX_PARTICIPANTS = 10

    # @param thread_ids [Array<Integer>] The IDs of the threads to query.
    # @param preview [Boolean] Determines the number of participants to return.
    # @return [Hash<Integer, Hash>] A hash of thread IDs to participant data.
    def self.call(thread_ids:)
      return {} if thread_ids.blank?

      # We only want enough data for BasicUserSerializer, since the participants
      # are just showing username & avatar.
      thread_participant_stats = DB.query(<<~SQL, thread_ids: thread_ids)
        SELECT thread_participant_stats.*, users.username, users.name, users.uploaded_avatar_id FROM (
          SELECT chat_messages.thread_id, chat_messages.user_id, COUNT(*) AS message_count,
            ROW_NUMBER() OVER (PARTITION BY chat_messages.thread_id ORDER BY COUNT(*) DESC) AS row_number
          FROM chat_messages
          INNER JOIN chat_threads ON chat_threads.id = chat_messages.thread_id
          INNER JOIN user_chat_thread_memberships ON user_chat_thread_memberships.thread_id = chat_threads.id
            AND user_chat_thread_memberships.user_id = chat_messages.user_id
          WHERE chat_messages.thread_id IN (:thread_ids)
          AND chat_messages.deleted_at IS NULL
          GROUP BY chat_messages.thread_id, chat_messages.user_id
        ) AS thread_participant_stats
        INNER JOIN users ON users.id = thread_participant_stats.user_id
        ORDER BY thread_participant_stats.thread_id ASC, thread_participant_stats.message_count DESC, thread_participant_stats.user_id ASC
      SQL

      most_recent_participants = DB.query(<<~SQL, thread_ids: thread_ids)
        SELECT DISTINCT ON (thread_id) chat_messages.thread_id, chat_messages.user_id,
          users.username, users.name, users.uploaded_avatar_id
        FROM chat_messages
        INNER JOIN chat_threads ON chat_threads.id = chat_messages.thread_id
        INNER JOIN user_chat_thread_memberships ON user_chat_thread_memberships.thread_id = chat_threads.id
          AND user_chat_thread_memberships.user_id = chat_messages.user_id
        INNER JOIN users ON users.id = chat_messages.user_id
        WHERE chat_messages.thread_id IN (:thread_ids)
        AND chat_messages.deleted_at IS NULL
        ORDER BY chat_messages.thread_id ASC, chat_messages.created_at DESC
      SQL
      most_recent_participants =
        most_recent_participants.reduce({}) do |hash, mrm|
          hash[mrm.thread_id] = {
            id: mrm.user_id,
            username: mrm.username,
            name: mrm.name,
            uploaded_avatar_id: mrm.uploaded_avatar_id,
          }
          hash
        end

      thread_participants = {}
      thread_participant_stats.each do |thread_participant_stat|
        thread_id = thread_participant_stat.thread_id
        thread_participants[thread_id] ||= {}
        thread_participants[thread_id][:users] ||= []
        thread_participants[thread_id][:total_count] ||= 0

        # If we want to return more of the top N users in the thread we
        # can just increase the number here.
        if thread_participants[thread_id][:users].length < (MAX_PARTICIPANTS - 1) &&
             thread_participant_stat.user_id != most_recent_participants[thread_id][:id]
          thread_participants[thread_id][:users].push(
            {
              id: thread_participant_stat.user_id,
              username: thread_participant_stat.username,
              name: thread_participant_stat.name,
              uploaded_avatar_id: thread_participant_stat.uploaded_avatar_id,
            },
          )
        end

        thread_participants[thread_id][:total_count] += 1
      end

      # Always put the most recent participant at the end of the array.
      most_recent_participants.each do |thread_id, user|
        thread_participants[thread_id][:users].push(user)
      end

      thread_participants
    end
  end
end
