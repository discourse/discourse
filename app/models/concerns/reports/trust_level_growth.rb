# frozen_string_literal: true

module Reports::TrustLevelGrowth
  extend ActiveSupport::Concern

  class_methods do
    def report_trust_level_growth(report)
      report.modes = [:stacked_chart]

      filters = %w[
        tl1_reached
        tl2_reached
        tl3_reached
        tl4_reached
      ]

      sql = <<~SQL
      SELECT
        date(created_at),
        (
          count(*) filter (WHERE previous_value::integer < 1 AND new_value = '1')
        )  as tl1_reached,
        (
          count(*) filter (WHERE previous_value::integer < 2 AND new_value = '2')
        )  as tl2_reached,
        (
          count(*) filter (WHERE previous_value::integer < 3  AND new_value = '3')
        )  as tl3_reached,
        (
          count(*) filter (WHERE previous_value::integer < 4  AND new_value = '4')
        )  as tl4_reached
      FROM user_histories
      WHERE (
        created_at >= '#{report.start_date}'
        AND created_at <= '#{report.end_date}'
      )
      AND (
        action = #{UserHistory.actions[:change_trust_level]}
        OR action = #{UserHistory.actions[:auto_trust_level_change]}
      )
      GROUP BY date(created_at)
      ORDER BY date(created_at)
      SQL

      data = Hash[ filters.collect { |x| [x, []] } ]

      builder = DB.build(sql)
      builder.query.each do |row|
        filters.each do |filter|
          data[filter] << {
            x: row.date.strftime("%Y-%m-%d"),
            y: row.instance_variable_get("@#{filter}")
          }
        end
      end

      tertiary = ColorScheme.hex_for_name('tertiary') || '0088cc'
      quaternary = ColorScheme.hex_for_name('quaternary') || 'e45735'

      requests = filters.map do |filter|
        color = report.rgba_color(quaternary)

        if filter == "tl1_reached"
          color = report.lighten_color(tertiary, 0.25)
        end
        if filter == "tl2_reached"
          color = report.rgba_color(tertiary)
        end
        if filter == "tl3_reached"
          color = report.lighten_color(quaternary, 0.25)
        end

        {
          req: filter,
          label: I18n.t("reports.trust_level_growth.xaxis.#{filter}"),
          color: color,
          data: data[filter]
        }
      end

      report.data = requests
    end
  end
end
