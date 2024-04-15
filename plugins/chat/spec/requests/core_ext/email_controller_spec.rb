# frozen_string_literal: true

describe EmailController do
  describe "unsubscribing from chat email settings" do
    fab!(:user)

    it "updates an user chat summary frequency" do
      SiteSetting.chat_enabled = true
      never_freq = "never"
      key = UnsubscribeKey.create_key_for(user, "chat_summary")
      user.user_option.send_chat_email_when_away!

      post "/email/unsubscribe/#{key}.json", params: { chat_email_frequency: never_freq }

      expect(response.status).to eq(302)

      get response.redirect_url

      expect(body).to include(user.email)
      expect(user.user_option.reload.chat_email_frequency).to eq(never_freq)
    end
  end
end
