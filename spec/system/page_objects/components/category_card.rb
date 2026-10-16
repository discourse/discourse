# frozen_string_literal: true

module PageObjects
  module Components
    class CategoryCard < PageObjects::Components::Base
      CARD_CONTENT_SELECTOR = ".category-card .card-content"

      def closed?
        have_count(0).matches?(browser_root.locator(CARD_CONTENT_SELECTOR).filter(visible: true))
      end

      def showing_category?(category)
        contain_text([browser_text_pattern(category.name)], useInnerText: true).matches?(
          browser_root.locator(
            "#{CARD_CONTENT_SELECTOR} .names__primary a[href='#{category.url}']",
          ).filter(visible: true),
        )
      end
    end
  end
end
