# frozen_string_literal: true

RSpec.describe Chat::AddUsersToChannel do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(usernames: [], channel_id: nil) }

    it { is_expected.to validate_presence_of :channel_id }
    it { is_expected.to validate_presence_of :usernames if :groups.blank? }
    it { is_expected.to validate_presence_of :groups if :usernames.blank? }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:users) { Fabricate.times(5, :user) }
    fab!(:direct_message) { Fabricate(:direct_message, users: [current_user], group: true) }
    fab!(:channel) { Fabricate(:direct_message_channel, chatable: direct_message) }
    fab!(:group_user_1) { Fabricate(:user) }
    fab!(:group_user_2) { Fabricate(:user) }
    fab!(:group) { Fabricate(:public_group, users: [group_user_1, group_user_2]) }

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { channel_id: channel.id, usernames: users.map(&:username) } }
    let(:dependencies) { { guardian: } }

    context "when all steps pass" do
      before { channel.add(current_user) }

      it { is_expected.to run_successfully }

      it "fetches users to add" do
        expect(result.target_users.map(&:username)).to contain_exactly(*users.map(&:username))
      end

      it "includes users from groups" do
        params.merge!(groups: [group.name])
        expect(result.target_users.map(&:username)).to include(
          group_user_1.username,
          group_user_2.username,
        )
      end

      context "with user count validation" do
        before { SiteSetting.chat_max_direct_message_users = 8 }

        it "succeeds when usernames does not exceed limit" do
          expect { result }.to change { Chat::UserChatChannelMembership.count }.by(6)
          expect(result).to be_a_success
        end

        it "succeeds when usernames and groups does not exceed limit" do
          params.merge!(groups: [group.name])

          expect { result }.to change { Chat::UserChatChannelMembership.count }.by(8)
          expect(result).to be_a_success
        end
      end

      it "doesn't include existing direct message users" do
        Chat::DirectMessageUser.create!(user: users.first, direct_message: direct_message)

        expect(result.target_users.map(&:username)).to contain_exactly(
          *users[1..-1].map(&:username),
        )
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
        added_users = result.target_users

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

    context "when users exceed max direct message user limit" do
      before { SiteSetting.chat_max_direct_message_users = 4 }

      it { is_expected.to fail_a_policy(:satisfies_dms_max_users_limit) }
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
