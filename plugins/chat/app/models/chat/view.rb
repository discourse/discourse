# frozen_string_literal: true

module Chat
  class View
    attr_reader :user, :chat_channel, :chat_messages, :can_load_more_past, :can_load_more_future

    def initialize(
      chat_channel:,
      chat_messages:,
      user:,
      can_load_more_past: nil,
      can_load_more_future: nil
    )
      @chat_channel = chat_channel
      @chat_messages = chat_messages
      @user = user
      @can_load_more_past = can_load_more_past
      @can_load_more_future = can_load_more_future
    end

    def reviewable_ids
      return @reviewable_ids if defined?(@reviewable_ids)

      @reviewable_ids = @user.staff? ? get_reviewable_ids : nil
    end

    def user_flag_statuses
      return @user_flag_statuses if defined?(@user_flag_statuses)

      @user_flag_statuses = get_user_flag_statuses
    end

    private

    def get_reviewable_ids
      sql = <<~SQL
        SELECT
          target_id,
          MAX(r.id) reviewable_id
        FROM
          reviewables r
        JOIN
          reviewable_scores s ON reviewable_id = r.id
        WHERE
          r.target_id IN (:message_ids) AND
          r.target_type = :target_type AND
          s.status = :pending
        GROUP BY
          target_id
    SQL

      ids = {}

      DB
        .query(
          sql,
          pending: ReviewableScore.statuses[:pending],
          message_ids: @chat_messages.map(&:id),
          target_type: Chat::Message.sti_name,
        )
        .each { |row| ids[row.target_id] = row.reviewable_id }

      ids
    end

    def get_user_flag_statuses
      sql = <<~SQL
        SELECT
          target_id,
          s.status
        FROM
          reviewables r
        JOIN
          reviewable_scores s ON reviewable_id = r.id
        WHERE
          s.user_id = :user_id AND
          r.target_id IN (:message_ids) AND
          r.target_type = :target_type
    SQL

      statuses = {}

      DB
        .query(
          sql,
          message_ids: @chat_messages.map(&:id),
          user_id: @user.id,
          target_type: Chat::Message.sti_name,
        )
        .each { |row| statuses[row.target_id] = row.status }

      statuses
    end
  end
end
