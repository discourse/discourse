# frozen_string_literal: true

require "webrick"

describe "Discourse Connect", type: :system do
  let(:sso_secret) { SecureRandom.alphanumeric(32) }
  let(:sso_port) { 9876 }
  let(:sso_url) { "http://localhost:#{sso_port}/sso" }

  fab!(:user)
  fab!(:private_group) { Fabricate(:group, users: [user]) }
  fab!(:private_category) { Fabricate(:private_category, group: private_group) }
  fab!(:private_topic) { Fabricate(:topic, category: private_category) }
  fab!(:private_post) { Fabricate(:post, topic: private_topic) }

  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  before do
    setup_test_sso_server
    configure_discourse_connect
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

  private

  def setup_test_sso_server
    @server =
      WEBrick::HTTPServer.new(
        Port: sso_port,
        Logger: WEBrick::Log.new(File.open(File::NULL, "w")),
        AccessLog: [],
      )

    @server.mount_proc "/sso" do |req, res|
      decoded = Base64.decode64(req.query["sso"])
      params = Rack::Utils.parse_query(decoded)

      response_sso = DiscourseConnectBase.new
      response_sso.nonce = params["nonce"]
      response_sso.sso_secret = sso_secret
      response_sso.external_id = "foo-bar"
      response_sso.email = user.email
      response_sso.username = user.username

      res.status = 302
      res["Location"] = "#{params["return_sso_url"]}?#{response_sso.payload}"
    end

    @server_thread = Thread.new { @server.start }

    sleep 0.1 until server_responding?
  end

  def shutdown_test_sso_server
    @server&.shutdown
    @server_thread&.kill
  end

  def server_responding?
    Net::HTTP.get_response(URI(sso_url))
    true
  rescue StandardError
    false
  end

  def configure_discourse_connect
    SiteSetting.discourse_connect_url = sso_url
    SiteSetting.discourse_connect_secret = sso_secret
    SiteSetting.enable_discourse_connect = true
  end
end
