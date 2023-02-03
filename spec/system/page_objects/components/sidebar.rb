# frozen_string_literal: true

module PageObjects
  module Components
    class Sidebar < PageObjects::Components::Base
      def visible?
        page.has_css?("#d-sidebar")
      end

      def not_visible?
        page.has_no_css?("#d-sidebar")
      end

      def has_category_section_link?(category)
        page.has_link?(category.name, class: "sidebar-section-link")
      end
    end
  end
end
