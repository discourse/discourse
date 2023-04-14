# frozen_string_literal: true

module PageObjects
  module Pages
    class Discovery < PageObjects::Pages::Base
      def topic_list
        Components::TopicList.new
      end

      def category_drop
        element = page.find(".category-breadcrumb li:first-of-type .category-drop")
        Components::SelectKit.new(element)
      end

      def subcategory_drop
        element = page.find(".category-breadcrumb li:nth-of-type(2) .category-drop")
        Components::SelectKit.new(element)
      end

      def tag_drop
        element = page.find(".category-breadcrumb .tag-drop")
        Components::SelectKit.new(element)
      end
    end
  end
end
