# frozen_string_literal: true

module PageObjects
  module Pages
    class Signup < PageObjects::Pages::Base
      def open?
        has_css?(".signup-fullpage")
      end

      def closed?
        has_no_css?(".signup-fullpage")
      end

      def open
        visit("/signup")
        self
      end

      def open_from_header
        find(".sign-up-button").click
      end

      def click(selector)
        if page.has_css?("html.mobile-view", wait: 0)
          expect(page).to have_no_css(".d-modal.is-animating")
        end
        find(selector).click
      end

      def open_login
        click("#login-link")
      end

      def click_create_account(expect_success: true)
        try_until_success(timeout: 5) do
          click(".signup-fullpage .btn-primary")
          expect(page).to have_css(".signup-fullpage .btn-primary.is-loading") if expect_success
        end
      end

      def has_password_input?
        has_css?("#new-account-password")
      end

      def has_no_password_input?
        has_no_css?("#new-account-password")
      end

      def fill_input(selector, text)
        if page.has_css?("html.mobile-view", wait: 0)
          expect(page).to have_no_css(".d-modal.is-animating")
        end
        find(selector).fill_in(with: text)
      end

      def fill_email(email)
        fill_input("#new-account-email", email)
        self
      end

      def fill_username(username)
        fill_input("#new-account-username", username)
        self
      end

      def fill_name(name)
        fill_input("#new-account-name", name)
        self
      end

      def fill_password(password)
        fill_input("#new-account-password", password)
        self
      end

      def fill_code(code)
        fill_input("#inviteCode", code)
        self
      end

      def fill_custom_field(name, value)
        find(".user-field-#{name.downcase} input").fill_in(with: value)
        self
      end

      def has_valid_email?
        find(".create-account-email").has_css?("#account-email-validation.good")
      end

      def has_valid_username?
        find(".create-account__username").has_css?("#username-validation.good")
      end

      def has_valid_password?
        find(".create-account__password").has_css?("#password-validation.good")
      end

      def has_valid_fields?
        has_valid_email?
        has_valid_username?
        has_valid_password?
      end

      def click_social_button(provider)
        click(".btn-social.#{provider}")
      end
    end
  end
end
