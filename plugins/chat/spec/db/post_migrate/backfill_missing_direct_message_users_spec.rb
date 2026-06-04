# frozen_string_literal: true

require Rails.root.join(
          "plugins/chat/db/post_migrate/20260604011058_backfill_missing_direct_message_users.rb",
        )

RSpec.describe BackfillMissingDirectMessageUsers do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "backfills missing direct message users from direct message channel memberships" do
    user = Fabricate(:user)
    channel = Fabricate(:direct_message_channel)
    membership =
      Chat::UserChatChannelMembership.create!(
        user: user,
        chat_channel: channel,
        following: true,
        notification_level: Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
        created_at: 2.days.ago,
        updated_at: 1.day.ago,
      )

    expect { described_class.new.up }.to change {
      Chat::DirectMessageUser.exists?(
        user_id: user.id,
        direct_message_channel_id: channel.chatable_id,
      )
    }.from(false).to(true)

    direct_message_user =
      Chat::DirectMessageUser.find_by!(
        user_id: user.id,
        direct_message_channel_id: channel.chatable_id,
      )
    expect(direct_message_user.created_at.to_i).to eq(membership.created_at.to_i)
    expect(direct_message_user.updated_at.to_i).to eq(membership.updated_at.to_i)
  end

  it "backfills direct message users for memberships that are not following" do
    user = Fabricate(:user)
    channel = Fabricate(:direct_message_channel)

    Chat::UserChatChannelMembership.create!(
      user: user,
      chat_channel: channel,
      following: false,
      notification_level: Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
    )

    expect { described_class.new.up }.to change {
      Chat::DirectMessageUser.exists?(
        user_id: user.id,
        direct_message_channel_id: channel.chatable_id,
      )
    }.from(false).to(true)
  end

  it "does not create direct message users from category channel memberships" do
    user = Fabricate(:user)
    channel = Fabricate(:category_channel)

    Chat::UserChatChannelMembership.create!(
      user: user,
      chat_channel: channel,
      following: true,
      notification_level: Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
    )

    expect { described_class.new.up }.not_to change { Chat::DirectMessageUser.count }
  end

  it "does not duplicate existing direct message users" do
    user = Fabricate(:user)
    channel = Fabricate(:direct_message_channel)

    Chat::UserChatChannelMembership.create!(
      user: user,
      chat_channel: channel,
      following: true,
      notification_level: Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
    )
    Chat::DirectMessageUser.create!(user: user, direct_message: channel.chatable)

    expect { described_class.new.up }.not_to change { Chat::DirectMessageUser.count }
  end
end
