# frozen_string_literal: true

RSpec.describe Chat::Channel do
  subject(:channel) { Fabricate(:chat_channel) }

  fab!(:category_channel_1) { Fabricate(:category_channel) }
  fab!(:dm_channel_1) { Fabricate(:direct_message_channel) }

  it { is_expected.to validate_length_of(:description).is_at_most(500) }
  it { is_expected.to validate_length_of(:slug).is_at_most(100) }
  it { is_expected.to validate_length_of(:chatable_type).is_at_most(100) }
  it { is_expected.to validate_length_of(:type).is_at_most(100) }

  it "supports custom fields" do
    channel.custom_fields["test"] = "test"
    channel.save_custom_fields
    loaded_channel = Chat::Channel.find(channel.id)
    expect(loaded_channel.custom_fields["test"]).to eq("test")
    expect(Chat::ChannelCustomField.first.channel.id).to eq(channel.id)
  end

  describe ".last_message" do
    context "when there are no last message" do
      it "returns an instance of NullMessage" do
        expect(channel.last_message).to be_a(Chat::NullMessage)
      end
    end
  end

  describe ".find_by_id_or_slug" do
    subject(:find_channel) { described_class.find_by_id_or_slug(channel_id) }

    context "when the channel is a direct message one" do
      let(:channel_id) { dm_channel_1.id }

      it "finds it" do
        expect(find_channel).to eq dm_channel_1
      end
    end

    context "when the channel is a category one" do
      context "when providing its id" do
        let(:channel_id) { category_channel_1.id }

        it "finds it" do
          expect(find_channel).to eq category_channel_1
        end
      end

      context "when providing its slug" do
        let(:channel_id) { category_channel_1.slug }

        it "finds it" do
          expect(find_channel).to eq category_channel_1
        end
      end

      context "when providing its category slug" do
        let(:channel_id) { category_channel_1.category.slug }

        it "finds it" do
          expect(find_channel).to eq category_channel_1
        end
      end
    end

    context "when providing a non existent id" do
      let(:channel_id) { -1 }

      it "returns nothing" do
        expect(find_channel).to be_blank
      end
    end
  end

  describe "#relative_url" do
    context "when the slug is nil" do
      it "uses a - instead" do
        category_channel_1.slug = nil
        expect(category_channel_1.relative_url).to eq("/chat/c/-/#{category_channel_1.id}")
      end
    end

    context "when the slug is not nil" do
      before { category_channel_1.update!(slug: "some-cool-channel") }

      it "includes the slug for the channel" do
        expect(category_channel_1.relative_url).to eq(
          "/chat/c/some-cool-channel/#{category_channel_1.id}",
        )
      end
    end
  end

  describe ".ensure_consistency!" do
    fab!(:category_channel_2) { Fabricate(:category_channel) }

    describe "updating messages_count for all channels" do
      fab!(:category_channel_3) { Fabricate(:category_channel) }
      fab!(:category_channel_4) { Fabricate(:category_channel) }
      fab!(:dm_channel_2) { Fabricate(:direct_message_channel) }

      before do
        Fabricate(:chat_message, chat_channel: category_channel_1)
        Fabricate(:chat_message, chat_channel: category_channel_1)
        Fabricate(:chat_message, chat_channel: category_channel_1)

        Fabricate(:chat_message, chat_channel: category_channel_2)
        Fabricate(:chat_message, chat_channel: category_channel_2)
        Fabricate(:chat_message, chat_channel: category_channel_2)
        Fabricate(:chat_message, chat_channel: category_channel_2)

        Fabricate(:chat_message, chat_channel: category_channel_3)

        Fabricate(:chat_message, chat_channel: dm_channel_2)
        Fabricate(:chat_message, chat_channel: dm_channel_2)
      end

      it "counts correctly" do
        described_class.ensure_consistency!
        expect(category_channel_1.reload.messages_count).to eq(3)
        expect(category_channel_2.reload.messages_count).to eq(4)
        expect(category_channel_3.reload.messages_count).to eq(1)
        expect(category_channel_4.reload.messages_count).to eq(0)
        expect(dm_channel_1.reload.messages_count).to eq(0)
        expect(dm_channel_2.reload.messages_count).to eq(2)
      end

      it "does not count deleted messages" do
        category_channel_3.chat_messages.last.trash!
        described_class.ensure_consistency!
        expect(category_channel_3.reload.messages_count).to eq(0)
      end

      it "does not update deleted channels" do
        described_class.ensure_consistency!
        category_channel_3.chat_messages.last.trash!
        category_channel_3.trash!
        described_class.ensure_consistency!
        expect(category_channel_3.reload.messages_count).to eq(1)
      end
    end

    describe "updating user_count for all channels" do
      fab!(:user_1) { Fabricate(:user) }
      fab!(:user_2) { Fabricate(:user) }
      fab!(:user_3) { Fabricate(:user) }
      fab!(:user_4) { Fabricate(:user) }

      def create_memberships
        user_1.user_chat_channel_memberships.create!(
          chat_channel: category_channel_1,
          following: true,
        )
        user_1.user_chat_channel_memberships.create!(
          chat_channel: category_channel_2,
          following: true,
        )

        user_2.user_chat_channel_memberships.create!(
          chat_channel: category_channel_1,
          following: true,
        )
        user_2.user_chat_channel_memberships.create!(
          chat_channel: category_channel_2,
          following: true,
        )

        user_3.user_chat_channel_memberships.create!(
          chat_channel: category_channel_1,
          following: false,
        )
        user_3.user_chat_channel_memberships.create!(
          chat_channel: category_channel_2,
          following: true,
        )
      end

      it "sets the user_count correctly for each chat channel" do
        create_memberships

        described_class.ensure_consistency!

        expect(category_channel_1.reload.user_count).to eq(2)
        expect(category_channel_2.reload.user_count).to eq(3)
      end

      it "does not count suspended, non-activated, nor staged users" do
        user_1.user_chat_channel_memberships.create!(
          chat_channel: category_channel_1,
          following: true,
        )
        user_2.user_chat_channel_memberships.create!(
          chat_channel: category_channel_2,
          following: true,
        )
        user_3.user_chat_channel_memberships.create!(
          chat_channel: category_channel_2,
          following: true,
        )
        user_4.user_chat_channel_memberships.create!(
          chat_channel: category_channel_2,
          following: true,
        )
        user_2.update(suspended_till: 3.weeks.from_now)
        user_3.update(staged: true)
        user_4.update(active: false)

        described_class.ensure_consistency!

        expect(category_channel_1.reload.user_count).to eq(1)
        expect(category_channel_2.reload.user_count).to eq(0)
      end

      it "does not count archived, or read_only channels" do
        create_memberships

        category_channel_1.update!(status: :archived)
        described_class.ensure_consistency!
        expect(category_channel_1.reload.user_count).to eq(0)

        category_channel_1.update!(status: :read_only)
        described_class.ensure_consistency!
        expect(category_channel_1.reload.user_count).to eq(0)
      end

      it "publishes all the updated channels" do
        create_memberships

        messages = MessageBus.track_publish { described_class.ensure_consistency! }

        expect(messages.length).to eq(3)
        expect(messages.map(&:data)).to match_array(
          [
            { chat_channel_id: category_channel_1.id, memberships_count: 2 },
            { chat_channel_id: category_channel_2.id, memberships_count: 3 },
            { chat_channel_id: dm_channel_1.id, memberships_count: 2 },
          ],
        )

        messages = MessageBus.track_publish { described_class.ensure_consistency! }
        expect(messages.length).to eq(0)
      end
    end
  end

  describe "#allow_channel_wide_mentions" do
    it "defaults to true" do
      expect(category_channel_1.allow_channel_wide_mentions).to be(true)
    end

    it "cant be nullified" do
      expect { category_channel_1.update!(allow_channel_wide_mentions: nil) }.to raise_error(
        ActiveRecord::NotNullViolation,
      )
    end
  end

  describe "#latest_not_deleted_message_id" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:old_message) { Fabricate(:chat_message, chat_channel: channel) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel) }

    before { old_message.update!(created_at: 1.day.ago) }

    it "accepts an anchor message to only get messages of a lower id" do
      expect(channel.latest_not_deleted_message_id(anchor_message_id: message_1.id)).to eq(
        old_message.id,
      )
    end

    it "gets the latest message by created_at" do
      expect(channel.latest_not_deleted_message_id).to eq(message_1.id)
    end

    it "does not get other channel messages" do
      Fabricate(:chat_message)
      expect(channel.latest_not_deleted_message_id).to eq(message_1.id)
    end

    it "does not get thread replies" do
      thread = Fabricate(:chat_thread, channel: channel, old_om: true)
      message_1.update!(thread: thread)
      expect(channel.latest_not_deleted_message_id).to eq(old_message.id)
    end

    it "does get thread original message" do
      thread = Fabricate(:chat_thread, channel: channel)
      expect(channel.latest_not_deleted_message_id).to eq(thread.original_message_id)
    end

    it "does not get deleted messages" do
      message_1.trash!
      expect(channel.latest_not_deleted_message_id).to eq(old_message.id)
    end
  end
end
