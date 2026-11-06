# frozen_string_literal: true

module PageObjects
  module Modals
    class ReviseAndRejectPost < Base
      def initialize
        super(modal_selector: ".revise-and-reject-reviewable")
      end

      def fill_reason(reason)
        find(".revise-and-reject-reviewable__custom-reason").fill_in(with: reason)
      end

      def fill_feedback(feedback)
        find(".revise-and-reject-reviewable__feedback").fill_in(with: feedback)
      end

      def has_reason?(reason)
        has_field?(class: "revise-and-reject-reviewable__custom-reason", with: reason)
      end

      def has_feedback?(feedback)
        has_field?(class: "revise-and-reject-reviewable__feedback", with: feedback)
      end
    end
  end
end
