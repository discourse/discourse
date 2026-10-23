# frozen_string_literal: true

module PageObjects
  module Modals
    class Flag < PageObjects::Modals::Base
      BODY_SELECTOR = ".flag-modal-body"
      MODAL_SELECTOR = ".flag-modal"

      def choose_type(type)
        body.find("#radio_#{type}").click
      end

      def has_no_illegal_flag_choice?
        body.has_no_css?("#radio_illegal")
      end

      def has_wrapped_illegal_content_link?(label)
        body.has_css?(".flag-modal__report-illegal-content", text: label) do |link|
          link.evaluate_script(
            "this.closest('.d-modal__body').scrollWidth <= this.closest('.d-modal__body').clientWidth",
          )
        end
      end

      def has_illegal_content_description?
        body.has_css?(
          ".flag-modal__illegal-content-description",
          text:
            I18n.t(
              "js.flagging.illegal_content_report_description",
              reportLink: I18n.t("js.flagging.illegal_content_report_link"),
            ),
        )
      end

      def has_no_illegal_content_description?
        body.has_no_css?(".flag-modal__illegal-content-description")
      end

      def report_illegal_content
        body.click_link(I18n.t("js.flagging.illegal_content_report_link"))
      end

      def confirm_flag
        click_primary_button
      end

      def take_action(action)
        select_kit =
          PageObjects::Components::SelectKit.new(".d-modal__footer .reviewable-action-dropdown")
        select_kit.expand
        select_kit.select_row_by_value(action)
      end

      def fill_message(message)
        body.fill_in("message", with: message)
      end

      def check_confirmation
        body.check("confirmation")
      end

      def has_choices?(*choices)
        expect(body.all(".flag-action-type-details strong").map(&:text)).to eq(choices)
      end
    end
  end
end
