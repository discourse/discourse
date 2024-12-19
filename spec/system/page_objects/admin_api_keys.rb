# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminApiKeys < PageObjects::Pages::Base
      def visit_page
        page.visit "/admin/api/keys"
        self
      end

      def has_api_key_listed?(name)
        page.has_css?(table_selector, text: name)
      end

      def has_no_api_key_listed?(name)
        page.has_no_css?(table_selector, text: name)
      end

      def add_api_key(description:)
        page.find(".admin-page-header__actions", text: "Add API key").click

        form = page.find(".form-kit")
        form.find("input[name='description']").fill_in(with: description)
        form.find(".save").click
      end

      private

      def table_selector
        ".admin-api_keys__items"
      end
    end
  end
end
