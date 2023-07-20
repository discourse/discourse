# frozen_string_literal: true

RSpec.shared_examples "a chat channel model" do
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:staff) { Fabricate(:user, admin: true) }
  fab!(:group) { Fabricate(:group) }
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:private_category_channel) { Fabricate(:category_channel, chatable: private_category) }
  fab!(:direct_message_channel) { Fabricate(:direct_message_channel, users: [user1, user2]) }

  it { is_expected.to belong_to(:chatable) }
  it { is_expected.to belong_to(:direct_message).with_foreign_key(:chatable_id) }
  it { is_expected.to have_many(:chat_messages) }
  it { is_expected.to have_many(:user_chat_channel_memberships) }
  it { is_expected.to have_one(:chat_channel_archive) }
  it { is_expected.to delegate_method(:empty?).to(:chat_messages).with_prefix }
  it do
    is_expected.to define_enum_for(:status).with_values(
      open: 0,
      read_only: 1,
      closed: 2,
      archived: 3,
    ).without_scopes
  end

  describe "Validations" do
    it { is_expected.to validate_presence_of(:name).allow_nil }
    it do
      is_expected.to validate_length_of(:name).is_at_most(
        SiteSetting.max_topic_title_length,
      ).allow_nil
    end
  end

  describe ".public_channels" do
    context "when a category used as chatable is destroyed" do
      fab!(:category_channel_1) { Fabricate(:chat_channel, chatable: Fabricate(:category)) }
      fab!(:category_channel_2) { Fabricate(:chat_channel, chatable: Fabricate(:category)) }

      before { category_channel_1.chatable.destroy! }

      it "doesn’t list the channel" do
        ids = Chat::Channel.public_channels.pluck(:chatable_id)
        expect(ids).to_not include(category_channel_1.chatable_id)
        expect(ids).to include(category_channel_2.chatable_id)
      end
    end
  end

  describe "#closed!" do
    before { private_category_channel.update!(status: :open) }

    it "does nothing if user is not staff" do
      private_category_channel.closed!(user1)
      expect(private_category_channel.reload.open?).to eq(true)
    end

    it "closes the channel, logs a staff action, and sends an event" do
      events = []
      messages =
        MessageBus.track_publish do
          events = DiscourseEvent.track_events { private_category_channel.closed!(staff) }
        end

      expect(events).to include(
        event_name: :chat_channel_status_change,
        params: [{ channel: private_category_channel, old_status: "open", new_status: "closed" }],
      )
      expect(messages.first.channel).to eq("/chat/channel-status")
      expect(messages.first.data).to eq(
        { chat_channel_id: private_category_channel.id, status: "closed" },
      )
      expect(private_category_channel.reload.closed?).to eq(true)

      expect(
        UserHistory.exists?(
          acting_user_id: staff.id,
          action: UserHistory.actions[:custom_staff],
          custom_type: "chat_channel_status_change",
          new_value: :closed,
          previous_value: :open,
        ),
      ).to eq(true)
    end
  end

  describe "#open!" do
    before { private_category_channel.update!(status: :closed) }

    it "does nothing if user is not staff" do
      private_category_channel.open!(user1)
      expect(private_category_channel.reload.closed?).to eq(true)
    end

    it "does nothing if the channel is archived" do
      private_category_channel.update!(status: :archived)
      private_category_channel.open!(staff)
      expect(private_category_channel.reload.archived?).to eq(true)
    end

    it "opens the channel, logs a staff action, and sends an event" do
      events = []
      messages =
        MessageBus.track_publish do
          events = DiscourseEvent.track_events { private_category_channel.open!(staff) }
        end

      expect(events).to include(
        event_name: :chat_channel_status_change,
        params: [{ channel: private_category_channel, old_status: "closed", new_status: "open" }],
      )
      expect(messages.first.channel).to eq("/chat/channel-status")
      expect(messages.first.data).to eq(
        { chat_channel_id: private_category_channel.id, status: "open" },
      )
      expect(private_category_channel.reload.open?).to eq(true)

      expect(
        UserHistory.exists?(
          acting_user_id: staff.id,
          action: UserHistory.actions[:custom_staff],
          custom_type: "chat_channel_status_change",
          new_value: :open,
          previous_value: :closed,
        ),
      ).to eq(true)
    end
  end

  describe "#read_only!" do
    before { private_category_channel.update!(status: :open) }

    it "does nothing if user is not staff" do
      private_category_channel.read_only!(user1)
      expect(private_category_channel.reload.open?).to eq(true)
    end

    it "marks the channel read_only, logs a staff action, and sends an event" do
      events = []
      messages =
        MessageBus.track_publish do
          events = DiscourseEvent.track_events { private_category_channel.read_only!(staff) }
        end

      expect(events).to include(
        event_name: :chat_channel_status_change,
        params: [
          { channel: private_category_channel, old_status: "open", new_status: "read_only" },
        ],
      )
      expect(messages.first.channel).to eq("/chat/channel-status")
      expect(messages.first.data).to eq(
        { chat_channel_id: private_category_channel.id, status: "read_only" },
      )
      expect(private_category_channel.reload.read_only?).to eq(true)

      expect(
        UserHistory.exists?(
          acting_user_id: staff.id,
          action: UserHistory.actions[:custom_staff],
          custom_type: "chat_channel_status_change",
          new_value: :read_only,
          previous_value: :open,
        ),
      ).to eq(true)
    end
  end

  describe "#archived!" do
    before { private_category_channel.update!(status: :read_only) }

    it "does nothing if user is not staff" do
      private_category_channel.archived!(user1)
      expect(private_category_channel.reload.read_only?).to eq(true)
    end

    it "does nothing if already archived" do
      private_category_channel.update!(status: :archived)
      private_category_channel.archived!(user1)
      expect(private_category_channel.reload.archived?).to eq(true)
    end

    it "does nothing if the channel is not already readonly" do
      private_category_channel.update!(status: :open)
      private_category_channel.archived!(staff)
      expect(private_category_channel.reload.open?).to eq(true)
      private_category_channel.update!(status: :read_only)
      private_category_channel.archived!(staff)
      expect(private_category_channel.reload.archived?).to eq(true)
    end

    it "marks the channel archived, logs a staff action, and sends an event" do
      events = []
      messages =
        MessageBus.track_publish do
          events = DiscourseEvent.track_events { private_category_channel.archived!(staff) }
        end

      expect(events).to include(
        event_name: :chat_channel_status_change,
        params: [
          { channel: private_category_channel, old_status: "read_only", new_status: "archived" },
        ],
      )
      expect(messages.first.channel).to eq("/chat/channel-status")
      expect(messages.first.data).to eq(
        { chat_channel_id: private_category_channel.id, status: "archived" },
      )
      expect(private_category_channel.reload.archived?).to eq(true)

      expect(
        UserHistory.exists?(
          acting_user_id: staff.id,
          action: UserHistory.actions[:custom_staff],
          custom_type: "chat_channel_status_change",
          new_value: :archived,
          previous_value: :read_only,
        ),
      ).to eq(true)
    end
  end

  describe "#add" do
    before { group.add(user1) }

    it "creates a membership for the user and enqueues a job to update the count" do
      initial_count = private_category_channel.user_count

      membership = private_category_channel.add(user1)
      private_category_channel.reload

      expect(membership.following).to eq(true)
      expect(membership.user).to eq(user1)
      expect(membership.chat_channel).to eq(private_category_channel)
      expect(private_category_channel.user_count_stale).to eq(true)
      expect_job_enqueued(
        job: Jobs::Chat::UpdateChannelUserCount,
        args: {
          chat_channel_id: private_category_channel.id,
        },
      )
    end

    it "updates an existing membership for the user and enqueues a job to update the count" do
      membership =
        Chat::UserChatChannelMembership.create!(
          chat_channel: private_category_channel,
          user: user1,
          following: false,
        )

      private_category_channel.add(user1)
      private_category_channel.reload

      expect(membership.reload.following).to eq(true)
      expect(private_category_channel.user_count_stale).to eq(true)
      expect_job_enqueued(
        job: Jobs::Chat::UpdateChannelUserCount,
        args: {
          chat_channel_id: private_category_channel.id,
        },
      )
    end

    it "does nothing if the user is already a member" do
      membership =
        Chat::UserChatChannelMembership.create!(
          chat_channel: private_category_channel,
          user: user1,
          following: true,
        )

      expect(private_category_channel.user_count_stale).to eq(false)
      expect_not_enqueued_with(
        job: Jobs::Chat::UpdateChannelUserCount,
        args: {
          chat_channel_id: private_category_channel.id,
        },
      ) { private_category_channel.add(user1) }
    end

    it "does not recalculate user count if it's already been marked as stale" do
      private_category_channel.update!(user_count_stale: true)
      expect_not_enqueued_with(
        job: Jobs::Chat::UpdateChannelUserCount,
        args: {
          chat_channel_id: private_category_channel.id,
        },
      ) { private_category_channel.add(user1) }
    end
  end

  describe "#remove" do
    before do
      group.add(user1)
      @membership = private_category_channel.add(user1)
      private_category_channel.reload
      private_category_channel.update!(user_count_stale: false)
    end

    it "updates the membership for the user and decreases the count" do
      membership = private_category_channel.remove(user1)
      private_category_channel.reload

      expect(@membership.reload.following).to eq(false)
      expect(private_category_channel.user_count_stale).to eq(true)
      expect_job_enqueued(
        job: Jobs::Chat::UpdateChannelUserCount,
        args: {
          chat_channel_id: private_category_channel.id,
        },
      )
    end

    it "returns nil if the user doesn't have a membership" do
      expect(private_category_channel.remove(user2)).to eq(nil)
    end

    it "does nothing if the user is not following the channel" do
      @membership.update!(following: false)

      private_category_channel.remove(user1)
      private_category_channel.reload

      expect(private_category_channel.user_count_stale).to eq(false)
      expect_job_enqueued(
        job: Jobs::Chat::UpdateChannelUserCount,
        args: {
          chat_channel_id: private_category_channel.id,
        },
      )
    end

    it "does not recalculate user count if it's already been marked as stale" do
      private_category_channel.update!(user_count_stale: true)
      expect_not_enqueued_with(
        job: Jobs::Chat::UpdateChannelUserCount,
        args: {
          chat_channel_id: private_category_channel.id,
        },
      ) { private_category_channel.remove(user1) }
    end
  end
end
