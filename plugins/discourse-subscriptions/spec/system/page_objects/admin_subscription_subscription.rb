# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminSubscriptionSubscription < PageObjects::Pages::Base
      SUBSCRIPTIONS_TABLE_SELECTOR = "table.discourse-patrons-table"

      def visit_subscriptions
        visit("/admin/plugins/discourse-subscriptions/subscriptions")
        self
      end

      def has_subscription?(id)
        has_css?("#{SUBSCRIPTIONS_TABLE_SELECTOR} tr", text: id)
        self
      end

      def subscription_row(id)
        find("#{SUBSCRIPTIONS_TABLE_SELECTOR} tr", text: id)
      end

      def has_number_of_subscriptions?(count)
        has_css?("#{SUBSCRIPTIONS_TABLE_SELECTOR} tr", count:)
        self
      end

      def click_cancel_nth_row(row)
        find("#{SUBSCRIPTIONS_TABLE_SELECTOR} tr:nth-child(#{row}) button.btn-danger").click()
      end
    end
  end
end
