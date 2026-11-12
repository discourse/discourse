# frozen_string_literal: true

module PageObjects
  module Components
    class LocalDate < PageObjects::Components::Base
      def has_rendered_date?
        has_css?(".discourse-local-date.cooked-date")
      end

      def has_text_in_date?(text)
        has_css?(".discourse-local-date .relative-time", text: text)
      end
    end
  end
end
