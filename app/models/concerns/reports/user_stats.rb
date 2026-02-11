# frozen_string_literal: true

module Reports::UserStats
  extend ActiveSupport::Concern

  class_methods do
    def report_user_stats(report)
      report.modes = [Report::MODES[:donut_chart]]
      report.dates_filtering = false

      type_filter = report.filters.dig(:type) || "trust_level"

      report.add_filter(
        "type",
        type: "list",
        display: "buttons",
        default: type_filter,
        choices: [
          { id: "trust_level", name: I18n.t("reports.user_stats.types.trust_level") },
          { id: "type", name: I18n.t("reports.user_stats.types.type") },
        ],
      )

      report.data = []
      color_keys = report.colors.keys

      if type_filter == "type"
        report.labels = [
          { property: :x, title: I18n.t("reports.users_by_type.labels.type") },
          { property: :y, type: :number, title: I18n.t("reports.default.labels.count") },
        ]

        url = Proc.new { |key| "/admin/users/list/#{key}" }

        admins = User.real.admins.count
        if admins > 0
          report.data << {
            icon: "shield-halved",
            key: "admins",
            x: I18n.t("reports.users_by_type.xaxis_labels.admin"),
            y: admins,
            color: report.colors[color_keys[report.data.size % color_keys.size]],
          }
        end

        moderators = User.real.moderators.count
        if moderators > 0
          report.data << {
            icon: "shield-halved",
            key: "moderators",
            x: I18n.t("reports.users_by_type.yaxis_labels.admin"),
            y: moderators,
            color: report.colors[color_keys[report.data.size % color_keys.size]],
          }
        end

        suspended = User.real.suspended.count
        if suspended > 0
          report.data << {
            icon: "ban",
            key: "suspended",
            x: I18n.t("reports.users_by_type.yaxis_labels.suspended"),
            y: suspended,
            color: report.colors[color_keys[report.data.size % color_keys.size]],
          }
        end

        silenced = User.real.silenced.count
        if silenced > 0
          report.data << {
            icon: "ban",
            key: "silenced",
            x: I18n.t("reports.users_by_type.yaxis_labels.silenced"),
            y: silenced,
            color: report.colors[color_keys[report.data.size % color_keys.size]],
          }
        end
      else
        report.labels = [
          { property: :key, title: I18n.t("reports.users_by_trust_level.labels.level") },
          { property: :y, type: :number, title: I18n.t("reports.default.labels.count") },
        ]

        User
          .real
          .group("trust_level")
          .count
          .sort
          .each do |level, count|
            report.data << {
              key: TrustLevel.levels.key(level.to_i),
              x: level.to_i,
              y: count,
              color: report.colors[color_keys[report.data.size % color_keys.size]],
            }
          end
      end
    end
  end
end
