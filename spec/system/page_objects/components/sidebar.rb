# frozen_string_literal: true

module PageObjects
  module Components
    class Sidebar < PageObjects::Components::Base
      def visible?
        page.has_css?("#d-sidebar")
      end

      def has_category_section_link?(category)
        page.has_link?(category.name, class: "sidebar-section-link")
      end

      def open_new_custom_section
        find("button.add-section").click
      end

      def edit_custom_section(name)
        find(".sidebar-section-#{name.parameterize}").hover
        find(".sidebar-section-#{name.parameterize} button.sidebar-section-header-button").click
      end
    end
  end
end
