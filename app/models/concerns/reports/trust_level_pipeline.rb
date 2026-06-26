# frozen_string_literal: true

module Reports::TrustLevelPipeline
  extend ActiveSupport::Concern

  class_methods do
    def report_trust_level_pipeline(report)
      report.modes = [Report::MODES[:table]]
      report.labels = [
        { property: :name, title: I18n.t("reports.trust_level_pipeline.labels.level") },
        {
          property: :count,
          type: :number,
          title: I18n.t("reports.trust_level_pipeline.labels.count"),
        },
        { property: :share_formatted, title: I18n.t("reports.trust_level_pipeline.labels.share") },
      ]

      snapshot = User.real.group(:trust_level).count
      total_members = snapshot.values.sum

      # Members who joined this period. They arrive at the default trust level,
      # which is the funnel's entry point: the dashboard shows this as that
      # level's inflow, since members reach every other level by climbing but
      # reach the entry level by signing up.
      new_signups = User.real.where(created_at: report.start_date..report.end_date).count
      entry_level = SiteSetting.default_trust_level

      # A trust-level change is directional: moving to a higher level is a
      # promotion, moving to a lower level a demotion. The same move is a
      # departure from one level and an arrival at another, so we track all four
      # flows per level. The dashboard funnel reads the "in" flows (how many
      # members reached each level this period); the "out" flows are kept for
      # the report table and tooltips.
      promoted_in_by_tl = Hash.new(0)
      promoted_out_by_tl = Hash.new(0)
      demoted_in_by_tl = Hash.new(0)
      demoted_out_by_tl = Hash.new(0)
      total_up = 0
      total_down = 0

      moves_sql = <<~SQL
        WITH trust_changes AS MATERIALIZED (
          SELECT target_user_id, new_value, previous_value, created_at
          FROM user_histories
          WHERE action IN (:change_action, :auto_action)
        )
        SELECT
          new_value::integer AS new_tl,
          previous_value::integer AS prev_tl,
          COUNT(*) AS move_count
        FROM trust_changes
        WHERE created_at >= :start_date
          AND created_at <= :end_date
          AND previous_value ~ '^\\d+$'
          AND new_value ~ '^\\d+$'
          AND target_user_id IN (SELECT id FROM users WHERE id > 0)
        GROUP BY new_value::integer, previous_value::integer
      SQL

      DB
        .query(
          moves_sql,
          change_action: UserHistory.actions[:change_trust_level],
          auto_action: UserHistory.actions[:auto_trust_level_change],
          start_date: report.start_date,
          end_date: report.end_date,
        )
        .each do |row|
          next if row.new_tl == row.prev_tl
          if row.new_tl > row.prev_tl
            promoted_out_by_tl[row.prev_tl] += row.move_count
            promoted_in_by_tl[row.new_tl] += row.move_count
            total_up += row.move_count
          else
            demoted_out_by_tl[row.prev_tl] += row.move_count
            demoted_in_by_tl[row.new_tl] += row.move_count
            total_down += row.move_count
          end
        end

      report.data =
        TrustLevel.valid_range.to_a.reverse.map do |tl|
          count = snapshot.fetch(tl, 0)
          share = total_members.zero? ? 0.0 : (count.to_f / total_members * 100).round(2)
          {
            trust_level: tl,
            name: I18n.t("reports.trust_level_pipeline.levels.#{tl}"),
            count: count,
            share: share,
            share_formatted: "#{share}%",
            promoted_in: promoted_in_by_tl[tl],
            promoted_out: promoted_out_by_tl[tl],
            demoted_in: demoted_in_by_tl[tl],
            demoted_out: demoted_out_by_tl[tl],
            signups: tl == entry_level ? new_signups : 0,
          }
        end

      net = total_up - total_down

      direction =
        if net > 0
          "climbing"
        elsif net < 0
          "dropping"
        else
          "stable"
        end

      report.total = total_members
      report.prev_period = { direction: direction, net: net.abs }
    end
  end
end
