# frozen_string_literal: true

module Boards
  module Statistics
    def self.created_boards
      {
        last_day: Boards::Board.where("created_at > ?", 1.day.ago).count,
        "7_days": Boards::Board.where("created_at > ?", 7.days.ago).count,
        "30_days": Boards::Board.where("created_at > ?", 30.days.ago).count,
        previous_30_days:
          Boards::Board.where("created_at BETWEEN ? AND ?", 60.days.ago, 30.days.ago).count,
      }
    end

    def self.total_boards
      { count: Boards::Board.count }
    end

    def self.viewed_boards
      scope =
        Boards::BoardHistory.where(action: Boards::BoardHistory.actions[:board_viewed]).select(
          "DISTINCT board_id",
        )
      {
        last_day: scope.where("created_at > ?", 1.day.ago).count,
        "7_days": scope.where("created_at > ?", 7.days.ago).count,
        "30_days": scope.where("created_at > ?", 30.days.ago).count,
        previous_30_days: scope.where("created_at BETWEEN ? AND ?", 60.days.ago, 30.days.ago).count,
        count: scope.count,
      }
    end

    def self.active_boards
      scope =
        Boards::CardHistory.where(
          action: [
            Boards::CardHistory.actions[:card_viewed],
            Boards::CardHistory.actions[:card_created],
            Boards::CardHistory.actions[:card_edited],
            Boards::CardHistory.actions[:card_moved],
            Boards::CardHistory.actions[:card_assigned],
            Boards::CardHistory.actions[:card_unassigned],
            Boards::CardHistory.actions[:card_deleted],
          ],
        ).select("DISTINCT board_id")
      {
        last_day: scope.where("created_at > ?", 1.day.ago).count,
        "7_days": scope.where("created_at > ?", 7.days.ago).count,
        "30_days": scope.where("created_at > ?", 30.days.ago).count,
        previous_30_days: scope.where("created_at BETWEEN ? AND ?", 60.days.ago, 30.days.ago).count,
        count: scope.count,
      }
    end

    def self.combined_history_scope(card_actions, board_actions)
      card_scope =
        Boards::CardHistory.where(action: card_actions).select(:acting_user_id, :created_at)
      board_scope =
        Boards::BoardHistory.where(action: board_actions).select(:acting_user_id, :created_at)

      Boards::CardHistory.from(
        "(#{card_scope.to_sql} UNION ALL #{board_scope.to_sql}) combined_histories",
      )
    end
    private_class_method :combined_history_scope

    def self.active_users
      combined_scope =
        combined_history_scope(
          [Boards::CardHistory.actions[:card_viewed]],
          [Boards::BoardHistory.actions[:board_viewed]],
        ).select("DISTINCT acting_user_id")
      {
        last_day: combined_scope.where("created_at > ?", 1.day.ago).count,
        "7_days": combined_scope.where("created_at > ?", 7.days.ago).count,
        "30_days": combined_scope.where("created_at > ?", 30.days.ago).count,
        previous_30_days:
          combined_scope.where("created_at BETWEEN ? AND ?", 60.days.ago, 30.days.ago).count,
        count: combined_scope.count,
      }
    end

    def self.participating_users
      combined_scope =
        combined_history_scope(
          [
            Boards::CardHistory.actions[:card_created],
            Boards::CardHistory.actions[:card_edited],
            Boards::CardHistory.actions[:card_moved],
            Boards::CardHistory.actions[:card_assigned],
            Boards::CardHistory.actions[:card_unassigned],
            Boards::CardHistory.actions[:card_deleted],
          ],
          [Boards::BoardHistory.actions[:board_created]],
        ).select("DISTINCT acting_user_id")
      {
        last_day: combined_scope.where("created_at > ?", 1.day.ago).count,
        "7_days": combined_scope.where("created_at > ?", 7.days.ago).count,
        "30_days": combined_scope.where("created_at > ?", 30.days.ago).count,
        previous_30_days:
          combined_scope.where("created_at BETWEEN ? AND ?", 60.days.ago, 30.days.ago).count,
        count: combined_scope.count,
      }
    end
  end
end
