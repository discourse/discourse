# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminEmailTemplatesIndex < PageObjects::Pages::Base
      class TemplateRow < PageObjects::Components::Base
        def initialize(selector)
          @selector = selector
          @element = find(selector)
        end

        def edit_button
          @element.find(".admin-email-templates__edit-button")
        end

        def name_cell
          @element.find(".admin-email-templates__name")
        end
      end

      def visit
        page.visit("/admin/email/templates")
      end

      def template(id)
        TemplateRow.new("tr[data-template-id=\"#{id}\"]")
      end

      def filter_controls
        PageObjects::Components::AdminFilterControls.new(".admin-filter-controls")
      end

      def has_exact_count_templates_shown?(count)
        has_css?("tr[data-template-id]", count:)
      end
    end
  end
end
