# frozen_string_literal: true
RSpec.describe Chat::ChatableGroupSerializer do
  fab!(:group)
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:bot_user) { Fabricate(:bot) }

  subject(:serializer) { described_class.new(group, scope: Fabricate(:user).guardian, root: false) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_max_direct_message_users = 3

    group.add(user_1)
    group.add(user_2)
    group.add(bot_user)

    user_1.user_option.update!(chat_enabled: true)
    user_2.user_option.update!(chat_enabled: true)
    bot_user.user_option.update!(chat_enabled: true)
  end

  it "gets the correct chat_enabled_user_count, excluding bot users" do
    expect(serializer.chat_enabled_user_count).to eq(2)
  end

  it "gets correct can_chat based on chat_enabled_user_count and chat_max_direct_message_users" do
    expect(serializer.can_chat).to eq(true)
    SiteSetting.chat_max_direct_message_users = 2
    expect(serializer.can_chat).to eq(false)
  end
end
