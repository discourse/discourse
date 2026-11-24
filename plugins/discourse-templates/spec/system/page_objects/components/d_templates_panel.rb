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

      # Filters the list through whichever tag drop the panel renders.
      def filter_by_tag_name(name)
        if d_select_tag_drop?
          d_select_tag_drop.select_name(name)
        else
          tag_drop.expand
          tag_drop.select_row_by_name(name)
        end
        self
      end

      def filter_by_tag_value(value)
        if d_select_tag_drop?
          d_select_tag_drop.select_value(value)
        else
          tag_drop.expand
          tag_drop.select_row_by_value(value)
        end
        self
      end

      def has_templates?(*templates)
        has_css?("#{PANEL_SELECTOR} .template-item", count: templates.size) &&
          templates.all? { |template| has_css?("#template-item-#{template.id}") }
      end

      private

      def d_select_tag_drop?
        find("#{PANEL_SELECTOR} .tag-drop").matches_css?(".d-select", wait: 0)
      end

      def d_select_tag_drop
        PageObjects::Components::UiKit::DSelect.at("#{PANEL_SELECTOR} .tag-drop")
      end
    end
  end
end
