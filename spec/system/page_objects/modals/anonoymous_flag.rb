# frozen_string_literal: true

module PageObjects
  module Modals
    class AnonymousFlag < PageObjects::Modals::Base
      BODY_SELECTOR = ".anonymous-flag-modal__body"

      def has_dsa_reporting_description?
        body.has_css?(
          ".anonymous-flag-modal__dsa-description",
          text: "If you believe this content is illegal, submit a report for our team to review.",
        ) && body.has_no_css?("a[href^='mailto:']") &&
          body.has_no_text?(I18n.t("js.flagging.review_process_description"))
      end

      def report_illegal_content
        body.click_link(I18n.t("js.anonymous_flagging.report_link"))
      end
    end
  end
end
