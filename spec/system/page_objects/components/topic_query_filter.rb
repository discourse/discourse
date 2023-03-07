# frozen_string_literal: true

module PageObjects
  module Components
    class TopicQueryFilter < PageObjects::Components::Base
      def fill_in(text)
        page.fill_in(class: "topic-query-filter__input", with: text)

        page.click_button(
          I18n.t("js.filters.filter.button.label"),
          class: "topic-query-filter__button",
        )
      end
    end
  end
end
