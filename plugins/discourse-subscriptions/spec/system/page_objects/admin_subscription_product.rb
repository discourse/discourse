# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminSubscriptionProduct < PageObjects::Pages::Base
      PRODUCTS_TABLE_SELECTOR = "table.discourse-patrons-table"

      def visit_products
        visit("/admin/plugins/discourse-subscriptions/products")
        self
      end

      def has_product?(name)
        has_css?("table.discourse-patrons-table tr", text: name)
        self
      end

      def has_number_of_products?(count)
        has_css?("table.discourse-patrons-table tr", count:)
        self
      end

      def click_trash_nth_row(row)
        find("table.discourse-patrons-table tr:nth-child(#{row}) button.btn-danger").click()
      end
    end
  end
end
