# frozen_string_literal: true

module DiscourseGamification
  class GamificationLeaderboardScore < ::ActiveRecord::Base
    self.table_name = "gamification_leaderboard_scores"

    belongs_to :user
    belongs_to :leaderboard,
               class_name: "DiscourseGamification::GamificationLeaderboard",
               foreign_key: :leaderboard_id

    def self.enabled_scorables(leaderboard:)
      Scorable.subclasses.filter { it.enabled?(leaderboard:) }
    end

    def self.scorables_queries(leaderboard:)
      enabled_scorables(leaderboard:).map { "( #{it.query(leaderboard:)} )" }.join(" UNION ALL ")
    end

    def self.calculate_scores(leaderboard, since_date: Date.today, only_subclass: nil)
      queries =
        if only_subclass
          if !Scorable.category_scoped?(leaderboard:) || only_subclass.supports_category_scoping?
            only_subclass.query(leaderboard:)
          end
        else
          scorables_queries(leaderboard:)
        end

      DB.exec(
        "DELETE FROM gamification_leaderboard_scores WHERE leaderboard_id = :leaderboard_id AND date >= :since",
        since: since_date,
        leaderboard_id: leaderboard.id,
      )

      category_ids = Scorable.scorable_category_ids(leaderboard:)
      score_event_category_filter =
        if Scorable.category_scoped?(leaderboard:)
          "AND category_id IN (:category_ids)"
        elsif category_ids.present?
          "AND (category_id IS NULL OR category_id IN (:category_ids))"
        end

      score_event_query = <<~SQL
        SELECT user_id, date, SUM(points) AS points
        FROM gamification_score_events
        WHERE date >= :since #{score_event_category_filter}
        GROUP BY 1, 2
      SQL

      source_queries = [queries.presence, score_event_query].compact

      DB.exec(<<~SQL, since: since_date, leaderboard_id: leaderboard.id, category_ids:)
        INSERT INTO gamification_leaderboard_scores (leaderboard_id, user_id, date, score)
        SELECT :leaderboard_id, user_id, date, SUM(points) AS score
        FROM (
          #{source_queries.join(" UNION ALL ")}
        ) AS source
        JOIN users AS u ON u.id = source.user_id
        WHERE user_id IS NOT NULL
          AND (u.suspended_till IS NULL OR u.suspended_till < CURRENT_TIMESTAMP)
          AND u.active
        GROUP BY user_id, date
        ON CONFLICT (leaderboard_id, user_id, date) DO UPDATE
        SET score = EXCLUDED.score;
      SQL
    end

    def self.calculate_all(since_date: Date.today)
      GamificationLeaderboard
        .where("to_date IS NULL OR to_date >= ?", since_date)
        .find_each { |lb| calculate_scores(lb, since_date:) }
    end

    def self.merge_scores(source_user, target_user)
      DB.exec(<<~SQL, source_id: source_user.id, target_id: target_user.id)
        WITH new_scores AS (
          SELECT leaderboard_id, :target_id AS user_id, date, SUM(score) AS score
          FROM gamification_leaderboard_scores
          WHERE user_id IN (:source_id, :target_id)
          GROUP BY 1, 2, 3
        ) INSERT INTO gamification_leaderboard_scores (leaderboard_id, user_id, date, score)
          SELECT leaderboard_id, user_id, date, score
          FROM new_scores
          ON CONFLICT (leaderboard_id, user_id, date) DO UPDATE
          SET score = EXCLUDED.score;
      SQL

      DB.exec(<<~SQL, source_id: source_user.id)
        DELETE FROM gamification_leaderboard_scores
        WHERE user_id = :source_id;
      SQL
    end
  end
end

# == Schema Information
#
# Table name: gamification_leaderboard_scores
#
#  id             :bigint           not null, primary key
#  date           :date             not null
#  score          :integer          default(0), not null
#  leaderboard_id :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  idx_leaderboard_scores_lb_date       (leaderboard_id,date)
#  idx_leaderboard_scores_lb_user_date  (leaderboard_id,user_id,date) UNIQUE
#
