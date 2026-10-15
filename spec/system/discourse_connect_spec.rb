# frozen_string_literal: true

describe "Discourse Connect" do
  include DiscourseConnectHelpers

  let(:sso_secret) { SecureRandom.alphanumeric(32) }
  let!(:sso_port) { setup_test_discourse_connect_server(user:, sso_secret:) }
  let(:sso_url) { "http://localhost:#{sso_port}/sso" }

  before { configure_discourse_connect }

  shared_examples "redirects to SSO" do
    it "redirects to SSO" do
      wait_for do
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#current-user").filter(visible: true),
        )
      end
      expect(
        browser_root.locator("a[data-topic-id='#{private_topic.id}']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end
  end

  shared_examples "shows the homepage" do
    it "shows the homepage" do
      expect(
        browser_root.locator("a[data-topic-id='#{topic.id}']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end
  end

  shared_examples "shows the login splash" do
    it "shows the login splash" do
      expect(
        browser_root.locator(".login-page").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end
  end

  context "when using vanilla DiscourseConnect" do
    fab!(:user)
    fab!(:private_group) { Fabricate(:group, users: [user]) }
    fab!(:private_category) { Fabricate(:private_category, group: private_group) }
    fab!(:private_topic) { Fabricate(:topic, category: private_category) }
    fab!(:private_post) { Fabricate(:post, topic: private_topic) }

    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic:) }

    context "when login_required is false" do
      before { SiteSetting.login_required = false }

      context "when auth_immediately is false" do
        before { SiteSetting.auth_immediately = false }

        context "when visiting /" do
          before { browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) } }

          it_behaves_like "shows the homepage"
        end

        context "when visiting / and clicking the login button" do
          before do
            browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
            browser_root.locator(".login-button").filter(visible: true).click
          end

          it_behaves_like "redirects to SSO"
        end

        context "when visiting /login" do
          before do
            browser_page.goto("/login").tap { SystemBrowserBootstrap.wait_for(browser_page) }
          end

          it_behaves_like "redirects to SSO"
        end
      end

      context "when auth_immediately is true" do
        before { SiteSetting.auth_immediately = true }

        context "when visiting /" do
          before { browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) } }

          it_behaves_like "shows the homepage"
        end

        context "when visiting / and clicking the login button" do
          before do
            browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
            browser_root.locator(".login-button").filter(visible: true).click
          end

          it_behaves_like "redirects to SSO"
        end

        context "when visiting /login" do
          before do
            browser_page.goto("/login").tap { SystemBrowserBootstrap.wait_for(browser_page) }
          end

          it_behaves_like "redirects to SSO"
        end

        it "redirects the user back to the landing URL" do
          browser_page.goto(private_topic.url).tap { SystemBrowserBootstrap.wait_for(browser_page) }

          browser_root.locator(".login-button").filter(visible: true).click

          wait_for do
            PlaywrightMatchers.have_count(0).does_not_match?(
              browser_root.locator("#current-user").filter(visible: true),
            )
          end

          expect(browser_page).to PlaywrightMatchers.have_url(private_topic.relative_url)
        end
      end
    end

    context "when login_required is true" do
      before { SiteSetting.login_required = true }

      context "when auth_immediately is false" do
        before { SiteSetting.auth_immediately = false }

        context "when visiting /" do
          before { browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) } }

          it_behaves_like "shows the login splash"
        end

        context "when visiting / and clicking the login button" do
          before do
            browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
            browser_root.locator(".login-button").filter(visible: true).click
          end

          it_behaves_like "redirects to SSO"
        end

        context "when visiting /login" do
          before do
            browser_page.goto("/login").tap { SystemBrowserBootstrap.wait_for(browser_page) }
          end

          it_behaves_like "redirects to SSO"
        end
      end

      context "when auth_immediately is true" do
        before { SiteSetting.auth_immediately = true }

        context "when visiting /" do
          before { browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) } }

          it_behaves_like "redirects to SSO"
        end

        context "when visiting /login" do
          before do
            browser_page.goto("/login").tap { SystemBrowserBootstrap.wait_for(browser_page) }
          end

          it_behaves_like "redirects to SSO"
        end
      end
    end
  end

  private

  def configure_discourse_connect
    SiteSetting.discourse_connect_url = sso_url
    SiteSetting.discourse_connect_secret = sso_secret
    SiteSetting.enable_discourse_connect = true
  end
end
