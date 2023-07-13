# frozen_string_literal: true

describe UsersController do
  describe "#perform_account_activation" do
    let!(:channel) { Fabricate(:category_channel, auto_join_users: true) }

    before do
      Jobs.run_immediately!
      UsersController.any_instance.stubs(:honeypot_or_challenge_fails?).returns(false)
      SiteSetting.send_welcome_message = false
      SiteSetting.chat_enabled = true
    end

    it "triggers the auto-join process" do
      user = Fabricate(:user, last_seen_at: 1.minute.ago, active: false)
      email_token = Fabricate(:email_token, user: user)

      put "/u/activate-account/#{email_token.token}"

      expect(response.status).to eq(200)
      membership = Chat::UserChatChannelMembership.find_by(user: user, chat_channel: channel)
      expect(membership.following).to eq(true)
    end
  end
end
