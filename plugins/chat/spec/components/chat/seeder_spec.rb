# frozen_string_literal: true

describe Chat::Seeder do
  fab!(:staff_category) { Fabricate(:private_category, name: "Staff", group: Group[:staff]) }
  fab!(:general_category) { Fabricate(:category, name: "General") }

  before do
    SiteSetting.staff_category_id = staff_category.id
    SiteSetting.general_category_id = general_category.id
    Jobs.run_immediately!
  end

  def assert_channel_was_correctly_seeded(channel, users, category)
    expect(channel).to be_present
    expect(channel.auto_join_users).to eq(true)
    expect(channel.name).to eq(category.name)

    expect(category.custom_fields[Chat::HAS_CHAT_ENABLED]).to eq(true)

    member_ids =
      Chat::UserChatChannelMembership
        .automatic
        .where(chat_channel: channel, following: true)
        .pluck(:user_id)

    expect(member_ids).to contain_exactly(*users.map(&:id))
  end

  it "seeds default channels" do
    last_seen_at = 1.minute.ago

    admin = Fabricate(:admin, last_seen_at:, refresh_auto_groups: true)
    moderator = Fabricate(:moderator, last_seen_at:, refresh_auto_groups: true)
    tl0_user = Fabricate(:user, last_seen_at:, trust_level: 0)
    tl1_user = Fabricate(:user, last_seen_at:, trust_level: 1)

    Chat::Seeder.new.execute

    staff_channel = Chat::Channel.find_by(chatable_id: staff_category)
    general_channel = Chat::Channel.find_by(chatable_id: general_category)

    assert_channel_was_correctly_seeded(staff_channel, [admin, moderator], staff_category)
    assert_channel_was_correctly_seeded(
      general_channel,
      [admin, moderator, tl0_user, tl1_user],
      general_category,
    )

    expect(SiteSetting.needs_chat_seeded).to eq(false)
  end

  it "does nothing when 'SiteSetting.needs_chat_seeded' is false" do
    SiteSetting.needs_chat_seeded = false

    expect { Chat::Seeder.new.execute }.not_to change { Chat::Channel.count }
  end
end
