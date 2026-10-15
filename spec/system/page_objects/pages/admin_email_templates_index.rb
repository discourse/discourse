# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminEmailTemplatesIndex < PageObjects::Pages::Base
      class TemplateRow < PageObjects::Components::Base
        def initialize(selector)
          @selector = selector
          @element = browser_root.locator(selector).filter(visible: true)
        end

        def edit_button
          @element.locator(".admin-email-templates__edit-button").filter(visible: true)
        end

        def name_cell
          @element.locator(".admin-email-templates__name").filter(visible: true)
        end

        def overridden?
          @element.get_attribute("class").include?("overridden")
        end
      end

      def visit
        browser_page
          .goto("/admin/email/templates")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      def template(id)
        TemplateRow.new("tr[data-template-id=\"#{id}\"]")
      end

      def filter_controls
        PageObjects::Components::DFilterControls.new(".d-filter-controls")
      end

      def only_overridden_checkbox
        browser_root.locator("#toggle-overridden").filter(visible: true)
      end

      def has_exact_count_templates_shown?(count)
        PlaywrightMatchers.have_count(count).matches?(
          browser_root.locator("tr[data-template-id]").filter(visible: true),
        )
      end
    end
  end
end
