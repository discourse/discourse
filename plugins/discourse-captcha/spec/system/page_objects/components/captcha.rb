# frozen_string_literal: true

module PageObjects
  module Components
    class Captcha < PageObjects::Components::Base
      def complete_hcaptcha
        within_frame(find("#h-captcha-field iframe")) { find("#checkbox").click }
        expect(page).to have_field("h-captcha-response", with: /.+/, visible: :all)
        self
      end

      def has_hcaptcha_container?
        page.has_css?("#h-captcha-field")
      end

      def has_no_hcaptcha_container?
        page.has_no_css?("#h-captcha-field")
      end

      def has_recaptcha_container?
        page.has_css?("#g-recaptcha")
      end

      def has_no_recaptcha_container?
        page.has_no_css?("#g-recaptcha")
      end

      def has_captcha_error?
        page.has_css?(".captcha-container + .alert-error") ||
          page.has_css?(".captcha-service-tip .bad")
      end

      def has_captcha_widget?
        has_hcaptcha_widget? || has_recaptcha_widget?
      end

      def has_hcaptcha_widget?
        page.has_css?("#h-captcha-field iframe")
      end

      def has_recaptcha_widget?
        page.has_css?("#g-recaptcha iframe")
      end
    end
  end
end
