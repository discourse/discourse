# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::ChatServiceFailure do
  describe ".failed_step_name" do
    fab!(:channel, :chat_channel)
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

    before { SiteSetting.chat_enabled = true }

    it "names the step that made the service fail" do
      UserSilencer.silence(user, Discourse.system_user)

      result =
        Chat::CreateMessage.call(
          guardian: user.guardian,
          params: {
            chat_channel_id: channel.id,
            message: "Hello",
          },
        )

      expect(described_class.failed_step_name(result)).to eq("policy.no_silenced_user")
    end
  end
end
