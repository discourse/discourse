# frozen_string_literal: true

RSpec.describe Chat::Action::PublishAndFollowDirectMessageChannel do
  subject(:action) { described_class.call(channel_membership: membership) }

  fab!(:user)

  let(:membership) { user.user_chat_channel_memberships.last }

  before { channel.add(user) }

  context "when channel is not a direct message one" do
    fab!(:channel) { Fabricate(:chat_channel) }

    it "does not publish anything" do
      Chat::Publisher.expects(:publish_new_channel).never
      action
    end

    it "does not update memberships" do
      expect { action }.not_to change {
        channel.user_chat_channel_memberships.where(following: true).count
      }
    end
  end

  context "when channel is a direct message one" do
    fab!(:channel) { Fabricate(:direct_message_channel) }

    context "when no users allow communication" do
      it "does not publish anything" do
        Chat::Publisher.expects(:publish_new_channel).never
        action
      end

      it "does not update memberships" do
        expect { action }.not_to change {
          channel.user_chat_channel_memberships.where(following: true).count
        }
      end
    end

    context "when at least one user allows communication" do
      before { channel.user_chat_channel_memberships.update_all(following: false) }

      it "publishes the channel" do
        user_ids = channel.user_chat_channel_memberships.map(&:user_id)
        Chat::Publisher.expects(:publish_new_channel).with(channel, includes(*user_ids))
        action
      end

      it "sets autofollow for these users" do
        expect { action }.to change {
          channel.user_chat_channel_memberships.where(following: true).count
        }.by(3)
      end
    end
  end
end
