# frozen_string_literal: true

module PageObjects
  module Components
    class Filter < PageObjects::Components::Base
      def filter(text)
        page.find(".sidebar-filter__input").fill_in(with: text)
        self
      end

      def clear
        page.find(".sidebar-filter__clear").click
        self
      end
    end
  end
end
