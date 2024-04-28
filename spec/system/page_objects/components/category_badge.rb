# frozen_string_literal: true

module PageObjects
  module Components
    class CategoryBadge < PageObjects::Components::Base
      SELECTOR = ".badge-category__wrapper"

      def find_for_category(category)
        find(category_selector(category))
      end

      def category_selector(category)
        "#{SELECTOR} .badge-category[data-category-id='#{category.id}']"
      end
    end
  end
end
