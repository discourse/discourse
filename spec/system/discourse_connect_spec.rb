# frozen_string_literal: true

describe "Discourse Connect", type: :system do
  include SsoHelpers

  let(:sso_secret) { SecureRandom.alphanumeric(32) }
  let(:sso_port) { 9876 }
  let(:sso_url) { "http://localhost:#{sso_port}/sso" }

  before do
    configure_discourse_connect
    setup_test_sso_server(user:, sso_secret:, sso_port:, sso_url:)
  end

  after { shutdown_test_sso_server }

  shared_examples "redirects to SSO" do
    it "redirects to SSO" do
      wait_for { has_css?("#current-user") }
      expect(page).to have_css("a[data-topic-id='#{private_topic.id}']")
    end
  end

  shared_examples "shows the homepage" do
    it "shows the homepage" do
      expect(page).to have_css("a[data-topic-id='#{topic.id}']")
    end
  end

  shared_examples "shows the login splash" do
    it "shows the login splash" do
      expect(page).to have_css(".login-page")
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
          before { visit "/" }
          it_behaves_like "shows the homepage"
        end

        context "when visiting / and clicking the login button" do
          before do
            visit "/"
            find(".login-button").click
          end

          it_behaves_like "redirects to SSO"
        end

        context "when visiting /login" do
          before { visit "/login" }
          it_behaves_like "redirects to SSO"
        end
      end

      context "when auth_immediately is true" do
        before { SiteSetting.auth_immediately = true }

        context "when visiting /" do
          before { visit "/" }
          it_behaves_like "shows the homepage"
        end

        context "when visiting / and clicking the login button" do
          before do
            visit "/"
            find(".login-button").click
          end

          it_behaves_like "redirects to SSO"
        end

        context "when visiting /login" do
          before { visit "/login" }
          it_behaves_like "redirects to SSO"
        end

        it "redirects the user back to the landing URL" do
          visit private_topic.url

          find(".login-button").click

          wait_for { has_css?("#current-user") }

          expect(page).to have_current_path(private_topic.relative_url)
        end
      end
    end

    context "when login_required is true" do
      before { SiteSetting.login_required = true }

      context "when auth_immediately is false" do
        before { SiteSetting.auth_immediately = false }

        context "when visiting /" do
          before { visit "/" }
          it_behaves_like "shows the login splash"
        end

        context "when visiting / and clicking the login button" do
          before do
            visit "/"
            find(".login-button").click
          end

          it_behaves_like "redirects to SSO"
        end

        context "when visiting /login" do
          before { visit "/login" }
          it_behaves_like "redirects to SSO"
        end
      end

      context "when auth_immediately is true" do
        before { SiteSetting.auth_immediately = true }

        context "when visiting /" do
          before { visit "/" }
          it_behaves_like "redirects to SSO"
        end

        context "when visiting /login" do
          before { visit "/login" }
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
