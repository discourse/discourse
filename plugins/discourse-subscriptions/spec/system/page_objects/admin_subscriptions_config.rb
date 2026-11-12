# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminSubscriptionsConfig < PageObjects::Pages::Base
      def visit
        page.visit("/admin/plugins/discourse-subscriptions")
        self
      end

      def has_tabs?(*labels)
        labels.all? { |label| has_css?(".admin-plugin-config-page__top-nav-item", text: label) }
      end

      def click_tab(label)
        find(".admin-plugin-config-page__top-nav-item", text: label).click
      end

      def has_stripe_unconfigured_notice?
        has_css?(
          ".discourse-subscriptions-unconfigured .admin-config-area-empty-list__cta-button",
          text: I18n.t("js.discourse_subscriptions.admin.configure_stripe"),
        )
      end
    end
  end
end
