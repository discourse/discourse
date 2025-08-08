# frozen_string_literal: true

module Reports::AssociatedAccountsByProvider
  extend ActiveSupport::Concern

  class_methods do
    def report_associated_accounts_by_provider(report)
      report.data = []
      report.modes = [Report::MODES[:table]]
      report.dates_filtering = false

      report.labels = [
        { property: :x, title: I18n.t("reports.associated_accounts_by_provider.labels.provider") },
        { property: :y, type: :number, title: I18n.t("reports.default.labels.count") },
      ]

      query =
        UserAssociatedAccount
          .joins(:user)
          .where(users: { active: true })
          .group(:provider_name)
          .count

      query.each do |provider_name, count|
        next if count == 0

        report.data << { icon: "plug", key: provider_name, x: provider_name.humanize, y: count }
      end

      report.data.sort_by! { |row| -row[:y] }
    end
  end
end
