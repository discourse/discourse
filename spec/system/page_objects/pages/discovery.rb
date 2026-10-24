# frozen_string_literal: true

module PageObjects
  module Pages
    class Discovery < PageObjects::Pages::Base
      def topic_list
        Components::TopicList.new
      end

      def topic_list_header
        Components::TopicListHeader.new
      end

      def category_drop
        Components::SelectKit.new(".category-breadcrumb li:first-of-type .category-drop")
      end

      def subcategory_drop
        Components::SelectKit.new(".category-breadcrumb li:nth-of-type(2) .category-drop")
      end

      # A DSelect driver when the new select controls render the tag drop, a select-kit one
      # otherwise.
      def tag_drop
        selector = ".category-breadcrumb .tag-drop"
        if has_css?(selector) && has_css?("#{selector}.d-select", wait: 0)
          Components::UiKit::DSelect.at(selector)
        else
          Components::SelectKit.new(selector)
        end
      end

      def nav_item(name)
        find("#navigation-bar .nav-item_#{name}")
      end
    end
  end
end
