# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::ChatUsage do
  fab!(:user)
  fab!(:public_category, :category)
  fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
  fab!(:public_channel) { Fabricate(:category_channel, chatable: public_category) }
  fab!(:private_channel) { Fabricate(:category_channel, chatable: private_category) }

  before { SiteSetting.chat_enabled = true }

  describe ".call" do
    context "with messages in public and private channels" do
      before do
        2.times do
          Fabricate(
            :chat_message,
            chat_channel: public_channel,
            user:,
            message: "hi",
            created_at: random_datetime,
          )
        end
        Fabricate(
          :chat_message,
          chat_channel: private_channel,
          user:,
          message: "hello",
          created_at: random_datetime,
        )
        direct_message =
          Fabricate(
            :chat_message,
            chat_channel: Fabricate(:direct_message_channel, users: [user, Fabricate(:user)]),
            user:,
            message: "hey you",
            created_at: random_datetime,
          )
        Fabricate(:chat_message_reaction, chat_message: direct_message)
      end

      it "returns nothing when there is too little chat activity to show" do
        expect(call_report).to be_nil
      end

      context "when above the minimum activity" do
        around do |example|
          stub_const(described_class, "MINIMUM_MESSAGES", 1) do
            stub_const(described_class, "MINIMUM_DM_CHANNELS", 0) { example.run }
          end
        end

        it "returns the chat statistics, with only public channels as favorites" do
          expect(call_report[:data]).to eq(
            total_messages: 4,
            favorite_channels: [
              {
                channel_id: public_channel.id,
                channel_slug: public_channel.slug,
                message_count: 2,
              },
            ],
            dm_message_count: 1,
            unique_dm_channels: 1,
            total_reactions_received: 1,
            avg_message_length: 4.0,
          )
        end
      end
    end
  end

  describe ".filter_for_viewer" do
    it "drops favorite channels that are no longer public, even for the owner" do
      report = {
        data: {
          favorite_channels:
            [public_channel, private_channel].map { |channel| { channel_id: channel.id } },
        },
      }

      filtered = described_class.filter_for_viewer(report, guardian: user.guardian, for_user: user)

      expect(filtered[:data][:favorite_channels]).to eq([{ channel_id: public_channel.id }])
    end
  end
end
