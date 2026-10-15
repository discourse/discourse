# frozen_string_literal: true

module PageObjects
  module Pages
    class GroupForm < PageObjects::Pages::Base
      def add_automatic_email_domain(domain)
        select_kit =
          PageObjects::Components::SelectKit.new(".group-form-automatic-membership-automatic")
        select_kit.expand
        select_kit.search(domain)
        select_kit.select_row_by_value(domain)
        self
      end

      def click_save
        browser_root.locator(".group-form-save").filter(visible: true).click
        self
      end

      private

      def automatic_email_domain_multi_select
        browser_root.locator(".group-form-automatic-membership-automatic").filter(visible: true)
      end
    end
  end
end
