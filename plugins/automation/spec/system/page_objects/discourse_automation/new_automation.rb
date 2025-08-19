# frozen_string_literal: true

module PageObjects
  module Pages
    class NewAutomation < PageObjects::Pages::Base
      def visit
        super("/admin/plugins/automation/automation/new")
        self
      end

      def fill_name(name)
        find_field("automation-name").fill_in(with: name)
        self
      end

      def create
        find(".create-automation").click
        self
      end

      def has_error?(message)
        find(".form-errors").has_text?(message)
      end
    end
  end
end
