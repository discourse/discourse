# frozen_string_literal: true

module PageObjects
  module Components
    class CategoryBadge < PageObjects::Components::Base
      SELECTOR = ".badge-category__wrapper"

      def find_for_category(category)
        browser_root.locator(category_selector(category)).filter(visible: true)
      end

      def category_selector(category)
        "#{SELECTOR} .badge-category[data-category-id='#{category.id}']"
      end
    end
  end
end
