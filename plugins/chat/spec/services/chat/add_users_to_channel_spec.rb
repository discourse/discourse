# frozen_string_literal: true

RSpec.describe Chat::AddUsersToChannel do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(usernames: [], channel_id: nil) }

    it { is_expected.to validate_presence_of :channel_id }
    it { is_expected.to validate_presence_of :usernames }
  end

  describe ".call" do
    subject(:result) { described_class.call(params) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:users) { Fabricate.times(5, :user) }
    fab!(:direct_message) { Fabricate(:direct_message, users: [current_user], group: true) }
    fab!(:channel) { Fabricate(:direct_message_channel, chatable: direct_message) }

    let(:guardian) { Guardian.new(current_user) }
    let(:params) do
      { guardian: guardian, channel_id: channel.id, usernames: users.map(&:username) }
    end

    context "when all steps pass" do
      before { channel.add(current_user) }

      it "fetches users to add" do
        expect(result.users.map(&:username)).to contain_exactly(*users.map(&:username))
      end

      it "doesn't include existing direct message users" do
        Chat::DirectMessageUser.create!(user: users.first, direct_message: direct_message)

        expect(result.users.map(&:username)).to contain_exactly(*users[1..-1].map(&:username))
      end

      it "creates memberships" do
        expect { result }.to change { channel.user_chat_channel_memberships.count }.by(
          users.count + 1,
        ) # +1 for system user creating the notice message and added to the channel
      end

      it "creates direct messages users" do
        expect { result }.to change { ::Chat::DirectMessageUser.count }.by(users.count + 1) # +1 for system user creating the notice message and added to the channel
      end

      it "updates users count" do
        expect { result }.to change { channel.reload.user_count }.by(users.count + 1) # +1 for system user creating the notice message and added to the channel
      end

      it "creates a chat message to show added users" do
        added_users = result.users

        channel.chat_messages.last.tap do |message|
          expect(message.message).to eq(
            I18n.t(
              "chat.channel.users_invited_to_channel",
              invited_users: added_users.map { |u| "@#{u.username}" }.join(", "),
              inviting_user: "@#{current_user.username}",
              count: added_users.count,
            ),
          )
          expect(message.user).to eq(Discourse.system_user)
        end
      end
    end

    context "when there are too many usernames" do
      before { SiteSetting.chat_max_direct_message_users = 2 }

      it { is_expected.to fail_a_contract }
    end

    context "when channel is not found" do
      before { params[:channel_id] = -999 }

      it { is_expected.to fail_to_find_a_model(:channel) }
    end

    context "when user don't have access to channel" do
      fab!(:channel) { Fabricate(:private_category_channel, group: Fabricate(:group)) }

      it { is_expected.to fail_a_policy(:can_add_users_to_channel) }
    end

    context "when channel is not a group" do
      before { direct_message.update!(group: false) }

      it { is_expected.to fail_a_policy(:can_add_users_to_channel) }
    end

    context "when channel is not a direct message channel" do
      fab!(:channel) { Fabricate(:chat_channel) }

      it { is_expected.to fail_a_policy(:can_add_users_to_channel) }
    end

    context "when user is not admin and not a member of the channel" do
      fab!(:current_user) { Fabricate(:user) }

      it { is_expected.to fail_a_policy(:can_add_users_to_channel) }
    end
  end
end
