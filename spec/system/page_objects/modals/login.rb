# frozen_string_literal: true

module PageObjects
  module Modals
    class Login < PageObjects::Modals::Base
      def open?
        super && has_css?(".login-modal")
      end

      def closed?
        super && has_no_css?(".login-modal")
      end

      def open
        visit("/login")
      end

      def open_from_header
        find(".login-button").click
      end

      def open_signup
        find("#new-account-link").click
      end

      def click_login
        find("#login-button").click
      end

      def email_login_link
        find("#email-login-link").click
      end

      def forgot_password
        find("#forgot-password-link").click
      end

      def fill_username(username)
        find("#login-account-name").fill_in(with: username)
      end

      def fill_password(password)
        find("#login-account-password").fill_in(with: password)
      end

      def fill(username: nil, password: nil)
        fill_username(username) if username
        fill_password(password) if password
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

      def select_passkey
        find(".btn-social.passkey-login-button").click
      end
    end
  end
end
