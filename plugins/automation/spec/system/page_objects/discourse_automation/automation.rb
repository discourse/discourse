# frozen_string_literal: true

module PageObjects
  module Pages
    class Automation < PageObjects::Pages::Base
      def visit(automation)
        super("/admin/plugins/automation/automation/#{automation.id}")
        self
      end

      def set_name(name)
        form.find('input[name="automation-name"]').set(name)
        self
      end

      def has_error?(message)
        form.has_content?(message)
      end

      def has_name?(name)
        form.find_field("automation-name", with: name)
      end

      def set_triggerables(triggerable)
        select_kit = PageObjects::Components::SelectKit.new(".triggerables")
        select_kit.expand
        select_kit.select_row_by_value(triggerable)
        self
      end

      def update
        form.find(".update-automation:not([disabled])").click
        self
      end

      def form
        @form ||= find(".discourse-automation-edit")
      end
    end
  end
end
