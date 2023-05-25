# frozen_string_literal: true

module PageObjects
  module Components
    class FormTemplateChooser < PageObjects::Components::Base
      COMPONENT_ID = ".form-template-chooser"

      def toggle_dropdown
        find(COMPONENT_ID).click
        self
      end

      def select_template_by_name(name)
        find(COMPONENT_ID).click
        find("#{COMPONENT_ID} .select-kit-collection li[data-name='#{name}']").click
        self
      end

      def has_selected_template?(name)
        page.has_css?("#{COMPONENT_ID} .selected-choice[data-name='#{name}']")
      end

      def has_dropdown_option?(name)
        page.has_css?("#{COMPONENT_ID} .select-kit-collection li[data-name='#{name}']")
      end

      def has_selected_header?(name)
        page.has_css?("#{COMPONENT_ID}.has-selection .select-kit-header[data-name='#{name}']")
      end
    end
  end
end
