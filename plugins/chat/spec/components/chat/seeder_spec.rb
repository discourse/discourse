# frozen_string_literal: true

describe Chat::Seeder do
  fab!(:staff_category) { Fabricate(:private_category, name: "Staff", group: Group[:staff]) }
  fab!(:general_category) { Fabricate(:category, name: "General") }

  before do
    SiteSetting.staff_category_id = staff_category.id
    SiteSetting.general_category_id = general_category.id
    Jobs.run_immediately!
  end

  def assert_channel_was_correctly_seeded(channel, group, category)
    expect(channel).to be_present
    expect(channel.auto_join_users).to eq(true)
    expect(channel.name).to eq(category.name)

    expect(category.custom_fields[Chat::HAS_CHAT_ENABLED]).to eq(true)

    expected_members_count = GroupUser.where(group: group).count
    memberships_count =
      Chat::UserChatChannelMembership.automatic.where(chat_channel: channel, following: true).count

    expect(memberships_count).to eq(expected_members_count)
  end

  it "seeds default channels" do
    last_seen_at = 1.minute.ago

    # By default, `chat_allowed_groups` is set to admins, moderators, and TL1
    Fabricate(:user, last_seen_at:, groups: [Group[:everyone], Group[:admins]])
    Fabricate(:user, last_seen_at:, groups: [Group[:everyone], Group[:moderators]])
    Fabricate(:user, last_seen_at:, groups: [Group[:everyone], Group[:trust_level_1]])

    Chat::Seeder.new.execute

    staff_channel = Chat::Channel.find_by(chatable_id: staff_category)
    general_channel = Chat::Channel.find_by(chatable_id: general_category)

    assert_channel_was_correctly_seeded(staff_channel, Group[:staff], staff_category)
    assert_channel_was_correctly_seeded(general_channel, Group[:everyone], general_category)

    expect(SiteSetting.needs_chat_seeded).to eq(false)
  end

  it "does nothing when 'SiteSetting.needs_chat_seeded' is false" do
    SiteSetting.needs_chat_seeded = false

    expect { Chat::Seeder.new.execute }.not_to change { Chat::Channel.count }
  end
end
