# frozen_string_literal: true

module PageObjects
  module Components
    class TopicQueryFilter < PageObjects::Components::Base
      def fill_in(text)
        page.fill_in(class: "topic-query-filter__filter-term", with: "#{text}\n")
      end

      def has_input_text?(text)
        page.has_field?(class: "topic-query-filter__filter-term", with: text)
      end
    end
  end
end
