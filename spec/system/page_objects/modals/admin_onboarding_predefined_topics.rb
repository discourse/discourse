# frozen_string_literal: true

module PageObjects
  module Modals
    class AdminOnboardingPredefinedTopics < PageObjects::Modals::Base
      MODAL_SELECTOR = ".predefined-topic-options-modal"

      def open?
        has_css?("#{MODAL_SELECTOR}")
      end

      def closed?
        has_no_css?("#{MODAL_SELECTOR}")
      end

      def topic_cards
        all(".predefined-topic-options-modal__card")
      end

      def topic_card_count
        topic_cards.count
      end

      def select_topic(index)
        topic_cards[index].find(".predefined-topic-options-modal__select-btn").click
      end

      def cancel
        find(".predefined-topic-options-modal__cancel-button").click
      end
    end
  end
end
