# frozen_string_literal: true

module Reports::UserStats
  extend ActiveSupport::Concern

  class_methods do
    def report_user_stats(report)
      report.modes = [Report::MODES[:donut_chart]]
      report.dates_filtering = false

      type_filter = report.filters.dig(:type) || "role"

      report.add_filter(
        "type",
        type: "list",
        display: "buttons",
        default: type_filter,
        choices: [
          { id: "role", name: I18n.t("reports.user_stats.types.role") },
          { id: "status", name: I18n.t("reports.user_stats.types.status") },
        ],
      )

      report.data = []
      color_keys = report.colors.keys

      if type_filter == "role"
        report.labels = [
          { property: :x, title: I18n.t("reports.users_by_type.labels.type") },
          { property: :y, type: :number, title: I18n.t("reports.default.labels.count") },
        ]

        # Trust levels (excluding admins and moderators)
        User
          .real
          .where(admin: false, moderator: false)
          .group("trust_level")
          .count
          .sort
          .each do |level, count|
            if count > 0
              report.data << {
                key: TrustLevel.levels.key(level.to_i),
                x: I18n.t("js.trust_levels.names.#{TrustLevel.levels[level.to_i]}"),
                y: count,
                color: report.colors[color_keys[report.data.size % color_keys.size]],
              }
            end
          end

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
            x: I18n.t("reports.users_by_type.xaxis_labels.moderator"),
            y: moderators,
            color: report.colors[color_keys[report.data.size % color_keys.size]],
          }
        end
      elsif type_filter == "status"
        report.labels = [
          { property: :x, title: I18n.t("reports.users_by_type.labels.type") },
          { property: :y, type: :number, title: I18n.t("reports.default.labels.count") },
        ]

        suspended = User.real.suspended.count
        if suspended > 0
          report.data << {
            icon: "ban",
            key: "suspended",
            x: I18n.t("reports.users_by_type.xaxis_labels.suspended"),
            y: suspended,
            color: report.colors[color_keys[report.data.size % color_keys.size]],
          }
        end

        silenced = User.real.silenced.count
        if silenced > 0
          report.data << {
            icon: "ban",
            key: "silenced",
            x: I18n.t("reports.users_by_type.xaxis_labels.silenced"),
            y: silenced,
            color: report.colors[color_keys[report.data.size % color_keys.size]],
          }
        end

        active = User.real.not_suspended.not_silenced.count
        if active > 0
          report.data << {
            icon: "check",
            key: "active",
            x: I18n.t("reports.users_by_type.xaxis_labels.active"),
            y: active,
            color: report.colors[color_keys[report.data.size % color_keys.size]],
          }
        end
      end
    end
  end
end
