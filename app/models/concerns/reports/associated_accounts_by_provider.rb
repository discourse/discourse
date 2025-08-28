# frozen_string_literal: true

module Reports::AssociatedAccountsByProvider
  extend ActiveSupport::Concern

  class_methods do
    def report_associated_accounts_by_provider(report)
      report.data = []
      report.modes = [Report::MODES[:table]]

      report.dates_filtering = false

      report.labels = [
        {
          property: :provider,
          title: I18n.t("reports.associated_accounts_by_provider.labels.provider"),
        },
        { property: :count, type: :number, title: I18n.t("reports.default.labels.count") },
      ]

      enabled_authenticators = Discourse.enabled_authenticators.map(&:name)

      if !enabled_authenticators.empty? && !SiteSetting.enable_discourse_connect
        query =
          UserAssociatedAccount
            .joins(:user)
            .where("provider_name IN (?)", enabled_authenticators)
            .where(users: { active: true })
            .group(:provider_name)
            .count

        # Add all enabled authenticators, including those with zero counts
        enabled_authenticators.each do |provider_name|
          count = query[provider_name] || 0

          report.data << {
            key: provider_name,
            provider: I18n.t("js.login.#{provider_name}.name"),
            count: count,
          }
        end
      end

      if SiteSetting.enable_discourse_connect
        discourse_connect_count =
          SingleSignOnRecord.joins(:user).where(users: { active: true }).distinct.count(:user_id)

        report.data << {
          key: "discourse_connect",
          provider: I18n.t("reports.associated_accounts_by_provider.labels.discourse_connect"),
          count: discourse_connect_count,
        }
      end

      total_users = Statistics.users[:count]

      # Don't output total for DiscourseConnect (it's the only auth method when enabled)
      if !SiteSetting.enable_discourse_connect
        report.data << {
          key: "total_users",
          provider: I18n.t("reports.associated_accounts_by_provider.labels.total_users"),
          count: total_users,
        }
      end

      # Add users with no associated accounts count (only considering enabled providers)
      users_with_accounts =
        if !enabled_authenticators.empty?
          UserAssociatedAccount
            .joins(:user)
            .where("provider_name IN (?)", enabled_authenticators)
            .where(users: { active: true })
            .distinct
            .count(:user_id)
        else
          0
        end

      users_with_accounts = discourse_connect_count if SiteSetting.enable_discourse_connect
      users_without_accounts = total_users - users_with_accounts

      report.data << {
        key: "no_accounts",
        provider:
          (
            if SiteSetting.enable_discourse_connect
              I18n.t("reports.associated_accounts_by_provider.labels.no_sso_accounts")
            else
              I18n.t("reports.associated_accounts_by_provider.labels.no_accounts")
            end
          ),
        count: users_without_accounts,
      }

      report.data.sort_by! { |row| -row[:count] }
    end
  end
end
