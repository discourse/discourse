# frozen_string_literal: true

module PageObjects
  module Components
    class NewTopicListToggleTab < PageObjects::Components::Base
      def initialize(name, selector)
        super()
        @name = name
        @selector = selector
      end

      def active?
        has_css?("#{@selector}.active")
      end

      def inactive?
        has_no_css?("#{@selector}.active") && has_css?(@selector)
      end

      def has_count?(count)
        expected_label =
          (
            if count > 0
              I18n.t("js.filters.new.#{@name}_with_count", count: count)
            else
              I18n.t("js.filters.new.#{@name}")
            end
          )
        find(@selector).text == expected_label
      end

      def click
        find(@selector).click
      end
    end
  end
end
