# frozen_string_literal: true

module PageObjects
  module Pages
    class Login < PageObjects::Pages::Base
      def open?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".login-fullpage").filter(visible: true),
        )
      end

      def closed?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".login-fullpage").filter(visible: true),
        )
      end

      def open
        browser_page.goto("/login").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def open_with_redirect(redirect_path)
        browser_page
          .goto("/login?redirect=#{redirect_path}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def open_from_header
        browser_root.locator(".login-button").filter(visible: true).click
      end

      def click(selector)
        if browser_root.locator("html.mobile-view").filter(visible: true).count != 0
          expect(
            browser_root.locator(".d-modal.is-animating").filter(visible: true),
          ).to PlaywrightMatchers.have_count(0)
        end
        browser_root.locator(selector).filter(visible: true).click
      end

      def open_signup
        click("#new-account-link")
      end

      def click_login
        click("#login-button")
      end

      def email_login_link
        click("#email-login-link")
      end

      def forgot_password
        click("#forgot-password-link")
      end

      def fill_input(selector, text)
        if browser_root.locator("html.mobile-view").filter(visible: true).count != 0
          expect(
            browser_root.locator(".d-modal.is-animating").filter(visible: true),
          ).to PlaywrightMatchers.have_count(0)
        end
        browser_root.locator(selector).filter(visible: true).fill(text)
      end

      def fill_username(username)
        fill_input("#login-account-name", username)
        self
      end

      def fill_password(password)
        fill_input("#login-account-password", password)
        self
      end

      def fill(username: nil, password: nil)
        fill_username(username) if username
        fill_password(password) if password
        self
      end

      def click_social_button(provider)
        click(".btn-social.#{provider}")
      end
    end
  end
end
