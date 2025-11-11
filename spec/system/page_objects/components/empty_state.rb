# frozen_string_literal: true

module PageObjects
  module Components
    class EmptyState < PageObjects::Components::Base
      def has_cta_text?(text)
        has_css?(".empty-state__cta", text: text)
      end

      def click_cta
        find(".empty-state__cta").click
      end
    end
  end
end
