# frozen_string_literal: true

RSpec.describe SessionController do
  describe "#create" do
    let(:password) { "myawesomepassword" }
    let(:admin) { Fabricate(:admin, password: password, last_seen_at: nil) }

    before do
      SiteSetting.chat_enabled = true
      EmailToken.confirm(Fabricate(:email_token, user: admin).token)
      admin.user_option.update!(dismissed_channel_retention_reminder: false)
    end

    it "dismisses the channel retention reminder on the first site admin's first login" do
      post "/session.json", params: { login: admin.username, password: password }

      expect(response.status).to eq(200)
      expect(session[:current_user_id]).to eq(admin.id)
      expect(admin.user_option.reload.dismissed_channel_retention_reminder).to eq(true)
    end

    it "leaves the channel retention reminder unchanged when chat is disabled" do
      SiteSetting.chat_enabled = false

      post "/session.json", params: { login: admin.username, password: password }

      expect(response.status).to eq(200)
      expect(session[:current_user_id]).to eq(admin.id)
      expect(admin.user_option.reload.dismissed_channel_retention_reminder).to eq(false)
    end
  end
end
