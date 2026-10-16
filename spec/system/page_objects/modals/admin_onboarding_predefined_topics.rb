# frozen_string_literal: true

module PageObjects
  module Modals
    class AdminOnboardingPredefinedTopics < PageObjects::Modals::Base
      MODAL_SELECTOR = ".predefined-topic-options-modal"

      def open?
        have_count(0).does_not_match?(
          browser_root.locator("#{MODAL_SELECTOR}").filter(visible: true),
        )
      end

      def closed?
        have_count(0).matches?(browser_root.locator("#{MODAL_SELECTOR}").filter(visible: true))
      end

      def topic_cards
        browser_root
          .locator(".predefined-topic-options-modal__card")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
      end

      def topic_card_count
        topic_cards.count
      end

      def select_topic(index)
        topic_cards[index].click
      end

      def select_option(option)
        browser_root
          .locator("#{MODAL_SELECTOR} [data-topic-option='#{option}']")
          .filter(visible: true)
          .click
      end

      def has_disabled_option?(option)
        have_count(0).does_not_match?(
          browser_root.locator(
            "#{MODAL_SELECTOR} [data-topic-option='#{option}'][disabled]",
          ).filter(visible: true),
        )
      end

      def cancel
        close
      end
    end
  end
end
