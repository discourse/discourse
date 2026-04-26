# frozen_string_literal: true

module PageObjects
  module Components
    class DTemplatesPanel < PageObjects::Components::Base
      PANEL_SELECTOR = ".d-templates-container"

      def open
        find(".toolbar-menu__options-trigger").click
        find("button[title='#{I18n.t("js.templates.insert_template")}']").click
        self
      end

      def tag_drop
        PageObjects::Components::SelectKit.new("#{PANEL_SELECTOR} .tag-drop")
      end

      def has_templates?(*templates)
        has_css?("#{PANEL_SELECTOR} .template-item", count: templates.size) &&
          templates.all? { |template| has_css?("#template-item-#{template.id}") }
      end
    end
  end
end
