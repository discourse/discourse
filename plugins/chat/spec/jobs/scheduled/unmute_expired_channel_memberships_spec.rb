# frozen_string_literal: true

RSpec.describe Jobs::Chat::UnmuteExpiredChannelMemberships do
  subject(:job) { described_class.new }

  fab!(:user)
  fab!(:channel, :category_channel)
  fab!(:membership) do
    Fabricate(:user_chat_channel_membership, chat_channel: channel, user: user, muted: true)
  end

  before { SiteSetting.chat_enabled = true }

  it "unmutes memberships whose mute has expired" do
    membership.update!(muted_until: 1.minute.from_now)
    other_membership =
      Fabricate(:user_chat_channel_membership, muted: true, muted_until: 1.minute.from_now)
    freeze_time 2.minutes.from_now

    messages = MessageBus.track_publish { job.execute }

    expect(membership.reload).to have_attributes(muted: false, muted_until: nil)
    expect(other_membership.reload).to have_attributes(muted: false, muted_until: nil)
    expect(messages.map(&:channel)).to contain_exactly(
      Chat::Publisher.user_channel_mute_message_bus_channel(user.id),
      Chat::Publisher.user_channel_mute_message_bus_channel(other_membership.user_id),
    )
    expect(messages.map { |message| [message.data, message.user_ids] }).to contain_exactly(
      [{ channel_id: channel.id, muted: false, muted_until: nil }, [user.id]],
      [
        { channel_id: other_membership.chat_channel_id, muted: false, muted_until: nil },
        [other_membership.user_id],
      ],
    )
  end

  it "keeps memberships muted until their mute expires" do
    membership.update!(muted_until: 1.hour.from_now)

    expect { job.execute }.not_to change { membership.reload.muted }
  end

  it "keeps memberships muted without an end time" do
    expect { job.execute }.not_to change { membership.reload.muted }
  end

  it "does nothing when chat is disabled" do
    membership.update!(muted_until: 1.minute.from_now)
    freeze_time 2.minutes.from_now
    SiteSetting.chat_enabled = false

    expect { job.execute }.not_to change { membership.reload.muted }
  end
end
