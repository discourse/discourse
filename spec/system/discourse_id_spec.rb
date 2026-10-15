# frozen_string_literal: true

describe "discourse login client auth" do
  include OmniauthHelpers

  before do
    OmniAuth.config.test_mode = true
    SiteSetting.discourse_id_client_id = "asdasd"
    SiteSetting.discourse_id_client_secret = "wadayathink"
    SiteSetting.enable_discourse_id = true

    OmniAuth.config.mock_auth[:discourse_id] = OmniAuth::AuthHash.new(
      provider: "discourse_id",
      uid: OmniauthHelpers::UID,
      info:
        OmniAuth::AuthHash::InfoHash.new(
          email: OmniauthHelpers::EMAIL,
          nickname: OmniauthHelpers::USERNAME,
        ),
    )
  end

  after { reset_omniauth_config(:discourse_id) }

  let(:signup_form) { PageObjects::Pages::Signup.new }

  context "when user does not exist" do
    context "when auth_skip_create_confirm is false" do
      before { SiteSetting.auth_skip_create_confirm = false }

      it "skips the signup form and creates the account directly" do
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        signup_form.open.click_social_button("discourse_id")
        expect(
          browser_root.locator(".login-welcome-header").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end
    end

    context "when auth_skip_create_confirm is true" do
      before { SiteSetting.auth_skip_create_confirm = true }

      it "skips the signup form and creates the account directly" do
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        signup_form.open.click_social_button("discourse_id")
        expect(
          browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end

      context "when full_name_requirement is required_at_signup" do
        before { SiteSetting.full_name_requirement = "required_at_signup" }

        it "shows the signup form when name is not provided by the provider" do
          browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
          signup_form.open.click_social_button("discourse_id")
          expect(signup_form).to be_open
          expect(
            browser_root.locator("#new-account-name").filter(visible: true),
          ).not_to PlaywrightMatchers.have_count(0)
        end

        context "when name is provided by the provider" do
          before do
            OmniAuth.config.mock_auth[:discourse_id] = OmniAuth::AuthHash.new(
              provider: "discourse_id",
              uid: OmniauthHelpers::UID,
              info:
                OmniAuth::AuthHash::InfoHash.new(
                  email: OmniauthHelpers::EMAIL,
                  nickname: OmniauthHelpers::USERNAME,
                  name: "John Doe",
                ),
            )
          end

          it "skips the signup form and creates the account directly" do
            browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
            signup_form.open.click_social_button("discourse_id")
            expect(
              browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
            ).not_to PlaywrightMatchers.have_count(0)
          end
        end
      end
    end
  end

  context "when user exists" do
    fab!(:user) do
      Fabricate(:user, email: OmniauthHelpers::EMAIL, username: OmniauthHelpers::USERNAME)
    end

    it "logs in user" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      signup_form.open.click_social_button("discourse_id")
      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end
  end
end
