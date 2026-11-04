# frozen_string_literal: true

module PageObjects
  module Modals
    class DsaNotice < Base
      MODAL_SELECTOR = ".dsa-notice-modal"

      def initialize
        super(modal_selector: MODAL_SELECTOR)
      end

      def go_back
        find(full_modal_selector).click_button("Go back")
      end

      def enter_email(email)
        form.field("email").fill_in(email)
      end

      def request_email_code
        find(full_modal_selector).click_button("Get email code")
      end

      def fill_verification_code(code)
        page.driver.with_playwright_page do |browser_page|
          browser_page.locator("#{full_modal_selector} .d-otp-input").fill(code)
        end
      end

      def enter_report(name:, explanation:)
        form.field("name").fill_in(name)
        form.field("explanation").fill_in(explanation)
      end

      def accept_declaration
        form.field("declaration").check
      end

      def submit_report
        form.submit
      end

      def has_post_url?(post)
        within(full_modal_selector) do
          has_field?(
            "Exact URL of the content",
            with: URI.join(page.current_url, post.url).to_s,
            disabled: :all,
          )
        end
      end

      def has_topic_url?(topic)
        within(full_modal_selector) do
          has_field?(
            "Exact URL of the content",
            with: URI.join(page.current_url, topic.relative_url).to_s,
            disabled: :all,
          )
        end
      end

      def has_disabled_submit?
        has_css?("#{full_modal_selector} button[type='submit']:disabled", text: "Submit report")
      end

      def has_verification_code_input?
        has_css?("#{full_modal_selector} .d-otp-input")
      end

      def has_no_email_input?
        has_no_css?("#{full_modal_selector} input[name='email']")
      end

      def has_verified_email?
        has_css?("#{full_modal_selector} button:disabled", text: "Verified") &&
          has_css?("#{full_modal_selector} input[name='email']:disabled")
      end

      def has_declaration?(text)
        has_css?("#{full_modal_selector} .form-kit__field[data-name='declaration']", text:)
      end

      def has_confirmation?
        has_css?("#{full_modal_selector} .dsa-notice__confirmation", text: "Report received")
      end

      private

      def form
        PageObjects::Components::FormKit.new("#{full_modal_selector} .form-kit")
      end
    end
  end
end
