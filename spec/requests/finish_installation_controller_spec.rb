# frozen_string_literal: true

RSpec.describe FinishInstallationController do
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
