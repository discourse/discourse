# frozen_string_literal: true

module PageObjects
  module Modals
    class Signup < PageObjects::Modals::Base
      def open?
        super && has_css?(".modal.create-account")
      end

      def closed?
        super && has_no_css?(".modal.create-account")
      end

      def open
        visit("/signup")
      end

      def open_from_header
        find(".sign-up-button").click
      end

      def open_login
        find("#login-link").click
      end

      def click_create_account
        find(".modal.create-account .btn-primary").click
      end

      def has_password_input?
        has_css?("#new-account-password")
      end

      def has_no_password_input?
        has_no_css?("#new-account-password")
      end

      def fill_email(email)
        find("#new-account-email").fill_in(with: email)
      end

      def fill_username(username)
        find("#new-account-username").fill_in(with: username)
      end

      def fill_name(name)
        find("#new-account-name").fill_in(with: name)
      end

      def fill_password(password)
        find("#new-account-password").fill_in(with: password)
      end

      def fill_code(code)
        find("#inviteCode").fill_in(with: code)
      end

      def fill_custom_field(name, value)
        find(".user-field-#{name.downcase} input").fill_in(with: value)
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

      def select_facebook
        find(".btn-social.facebook").click
      end

      def select_google
        find(".btn-social.google_oauth2").click
      end

      def select_github
        find(".btn-social.github").click
      end

      def select_twitter
        find(".btn-social.twitter").click
      end

      def select_discord
        find(".btn-social.discord").click
      end

      def select_linkedin
        find(".btn-social.linkedin_oidc").click
      end
    end
  end
end
