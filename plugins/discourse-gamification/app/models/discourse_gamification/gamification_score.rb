# frozen_string_literal: true

module ::DiscourseGamification
  class GamificationScore < ::ActiveRecord::Base
    self.table_name = "gamification_scores"

    belongs_to :user

    def self.enabled_scorables
      Scorable.subclasses.filter { _1.enabled? }
    end

    def self.scorables_queries
      enabled_scorables.map { "( #{_1.query} )" }.join(" UNION ALL ")
    end

    def self.calculate_scores(since_date: Date.today, only_subclass: nil)
      queries = only_subclass&.query || scorables_queries

      DB.exec(<<~SQL, since: since_date)
        DELETE FROM gamification_scores
        WHERE date >= :since;

        INSERT INTO gamification_scores (user_id, date, score)
        SELECT user_id, date, SUM(points) AS score
        FROM (
          #{queries}
          UNION ALL
          SELECT user_id, date, SUM(points) AS points
          FROM gamification_score_events
          WHERE date >= :since
          GROUP BY 1, 2
        ) AS source
        WHERE user_id IS NOT NULL
        GROUP BY 1, 2
        ON CONFLICT (user_id, date) DO UPDATE
        SET score = EXCLUDED.score;
      SQL
    end

    def self.merge_scores(source_user, target_user)
      DB.exec(<<~SQL, source_id: source_user.id, target_id: target_user.id)
        WITH new_scores AS (
          SELECT :target_id AS user_id, date, SUM(score) AS score
          FROM gamification_scores
          WHERE user_id IN (:source_id, :target_id)
          GROUP BY 1, 2
        ) INSERT INTO gamification_scores (user_id, date, score)
          SELECT user_id, date, score AS score
          FROM new_scores
          ON CONFLICT (user_id, date) DO UPDATE
          SET score = EXCLUDED.score;
      SQL

      DB.exec(<<~SQL, source_id: source_user.id)
        DELETE FROM gamification_scores
        WHERE user_id = :source_id;
      SQL
    end
  end
end

# == Schema Information
#
# Table name: gamification_scores
#
#  id      :bigint           not null, primary key
#  user_id :integer          not null
#  date    :date             not null
#  score   :integer          not null
#
# Indexes
#
#  index_gamification_scores_on_date              (date)
#  index_gamification_scores_on_user_id_and_date  (user_id,date) UNIQUE
#
