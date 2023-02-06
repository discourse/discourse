# frozen_string_literal: true

describe "Automatic user removal from channels" do
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:user) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    Group.refresh_automatic_groups!

    channel_1.add(user)

    Jobs.run_immediately!
  end

  it "removes the user who is no longer in a chat_allowed_groups" do
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_3]
    expect(UserChatChannelMembership.exists?(user: user, chat_channel: channel_1)).to eq(false)
  end
end
