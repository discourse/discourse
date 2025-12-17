# frozen_string_literal: true

RSpec.describe FinishInstallationController do
  describe "#index" do
    context "when has_login_hint is false" do
      before { SiteSetting.has_login_hint = false }

      it "doesn't allow access" do
        get "/finish-installation"
        expect(response.status).to eq(403)
      end
    end

    context "when has_login_hint is true" do
      before { SiteSetting.has_login_hint = true }

      it "allows access" do
        get "/finish-installation"
        expect(response.status).to eq(200)
      end

      context "when setting up Discourse ID" do
        before do
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with("DISCOURSE_SKIP_EMAIL_SETUP").and_return("1")
          GlobalSetting.stubs(:developer_emails).returns("admin@example.com")
        end

        it "enables the enable_discourse_id site setting and shows login button on success" do
          stub_request(:post, "https://id.discourse.com/challenge").to_return(
            status: 200,
            body: { domain: Discourse.current_hostname, token: "test_token" }.to_json,
          )
          stub_request(:post, "https://id.discourse.com/register").to_return(
            status: 200,
            body: { client_id: "test_client_id", client_secret: "test_client_secret" }.to_json,
          )

          get "/finish-installation"
          expect(response.status).to eq(200)
          expect(SiteSetting.enable_discourse_id).to eq(true)
          expect(SiteSetting.enable_local_logins).to eq(false)
          expect(response.body).to include("Login with Discourse ID")
          expect(response.body).to include("/finish-installation/redirect-discourse-id")
        end

        it "shows error message and no login button on failure" do
          stub_request(:post, "https://id.discourse.com/challenge").to_return(
            status: 500,
            body: "Internal Server Error",
          )

          get "/finish-installation"
          expect(response.status).to eq(200)
          expect(SiteSetting.enable_discourse_id).to eq(false)
          expect(response.body).not_to include("Login with Discourse ID")
          expect(response.body).to include("alert-error")
        end

        it "shows error when developer_emails is empty" do
          GlobalSetting.stubs(:developer_emails).returns("")

          stub_request(:post, "https://id.discourse.com/challenge").to_return(
            status: 200,
            body: { domain: Discourse.current_hostname, token: "test_token" }.to_json,
          )
          stub_request(:post, "https://id.discourse.com/register").to_return(
            status: 200,
            body: { client_id: "test_client_id", client_secret: "test_client_secret" }.to_json,
          )

          get "/finish-installation"
          expect(response.status).to eq(200)
          expect(response.body).not_to include("Login with Discourse ID")
          expect(response.body).to include("alert-error")
          expect(response.body).to include("No allowed emails configured")
        end
      end
    end
  end

  describe "#register" do
    before do
      SiteSetting.has_login_hint = true
      GlobalSetting.stubs(:developer_emails).returns("robin@example.com")
    end

    it "shows no_emails message when developer_emails is empty" do
      GlobalSetting.stubs(:developer_emails).returns("")
      get "/finish-installation/register"
      expect(response.status).to eq(200)
      expect(response.body).to include(I18n.t("finish_installation.register.no_emails"))
    end

    it "returns 400 when email is not in the allowed list" do
      post "/finish-installation/register.json",
           params: {
             email: "notrobin@example.com",
             username: "eviltrout",
             password: "disismypasswordokay",
           }
      expect(response.status).to eq(400)
    end
  end

  describe "#confirm_email" do
    it "renders without requiring has_login_hint" do
      SiteSetting.has_login_hint = false
      get "/finish-installation/confirm-email"
      expect(response.status).to eq(200)
    end
  end

  describe "#resend_email" do
    before do
      SiteSetting.has_login_hint = true
      GlobalSetting.stubs(:developer_emails).returns("robin@example.com")
    end

    it "resends activation email for user in session" do
      post "/finish-installation/register",
           params: {
             email: "robin@example.com",
             username: "eviltrout",
             password: "disismypasswordokay",
           }

      expect { put "/finish-installation/resend-email" }.to change {
        Jobs::CriticalUserEmail.jobs.size
      }.by(1)

      expect(response.status).to eq(200)
    end

    it "does nothing when user doesn't exist" do
      expect { put "/finish-installation/resend-email" }.not_to change {
        Jobs::CriticalUserEmail.jobs.size
      }

      expect(response.status).to eq(200)
    end
  end
end
