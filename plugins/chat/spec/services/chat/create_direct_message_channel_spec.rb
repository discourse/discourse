# frozen_string_literal: true

RSpec.describe Chat::CreateDirectMessageChannel do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(params) }

    let(:params) { { target_usernames: %w[lechuck elaine] } }

    it { is_expected.to validate_presence_of :target_usernames if :target_groups.blank? }
    it { is_expected.to validate_presence_of :target_groups if :target_usernames.blank? }

    context "when the target_usernames argument is a string" do
      let(:params) { { target_usernames: "lechuck,elaine" } }

      it "splits it into an array" do
        contract.validate
        expect(contract.target_usernames).to eq(%w[lechuck elaine])
      end
    end

    context "when the target_groups argument is a string" do
      let(:params) { { target_groups: "admins,moderators" } }

      it "splits it into an array" do
        contract.validate
        expect(contract.target_groups).to eq(%w[admins moderators])
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params) }

    fab!(:current_user) { Fabricate(:user, username: "guybrush", refresh_auto_groups: true) }
    fab!(:user_1) { Fabricate(:user, username: "lechuck") }
    fab!(:user_2) { Fabricate(:user, username: "elaine") }
    fab!(:user_3) { Fabricate(:user) }
    fab!(:group) { Fabricate(:public_group, users: [user_3]) }

    let(:guardian) { Guardian.new(current_user) }
    let(:target_usernames) { [user_1.username, user_2.username] }
    let(:name) { "" }
    let(:params) { { guardian: guardian, target_usernames: target_usernames, name: name } }

    context "when all steps pass" do
      it { is_expected.to run_successfully }

      it "updates user count" do
        expect(result.channel.user_count).to eq(3) # current user + user_1 + user_2
      end

      it "creates the channel" do
        expect { result }.to change { Chat::Channel.count }
        expect(result.channel.chatable).to have_attributes(
          user_ids: match_array([current_user.id, user_1.id, user_2.id]),
        )
      end

      it "makes all target users a member of the channel and updates all users to following" do
        expect { result }.to change { Chat::UserChatChannelMembership.count }.by(3)
        expect(result.channel.user_chat_channel_memberships.pluck(:user_id)).to match_array(
          [current_user.id, user_1.id, user_2.id],
        )
        result.channel.user_chat_channel_memberships.each do |membership|
          expect(membership).to have_attributes(
            following: false,
            muted: false,
            notification_level: "always",
          )
        end
      end

      it "includes users from target groups" do
        params.delete(:target_usernames)
        params.merge!(target_groups: [group.name])

        expect(result.channel.user_chat_channel_memberships.pluck(:user_id)).to include(user_3.id)
      end

      it "combines target_usernames and target_groups" do
        params.merge!(target_groups: [group.name])

        expect(result.channel.user_chat_channel_memberships.pluck(:user_id)).to contain_exactly(
          current_user.id,
          user_1.id,
          user_2.id,
          user_3.id,
        )
      end

      context "with user count validation" do
        before { SiteSetting.chat_max_direct_message_users = 4 }

        it "succeeds when target_usernames does not exceed limit" do
          expect { result }.to change { Chat::UserChatChannelMembership.count }.by(3)
          expect(result).to be_a_success
        end

        it "succeeds when target_usernames and target_groups does not exceed limit" do
          params.merge!(target_groups: [group.name])

          expect { result }.to change { Chat::UserChatChannelMembership.count }.by(4)
          expect(result).to be_a_success
        end

        it "succeeds when target_usernames is equal to max direct users" do
          SiteSetting.chat_max_direct_message_users = 2

          expect { result }.to change { Chat::UserChatChannelMembership.count }.by(3) # current user + user_1 + user_2
          expect(result).to be_a_success
        end
      end

      context "when there is an existing direct message channel for the target users" do
        context "when a name has been given" do
          let(:target_usernames) { [user_1.username] }
          let(:name) { "Monkey Island" }

          it "creates a second channel" do
            described_class.call(params)

            expect { result }.to change { Chat::Channel.count }.and change {
                    Chat::DirectMessage.count
                  }
          end
        end

        context "when the channel has more than one user" do
          let(:target_usernames) { [user_1.username, user_2.username] }

          it "creates a second channel" do
            described_class.call(params)

            expect { result }.to change { Chat::Channel.count }.and change {
                    Chat::DirectMessage.count
                  }
          end
        end

        context "when the channel has one user and no name" do
          let(:target_usernames) { [user_1.username] }

          it "reuses the existing channel" do
            existing_channel = described_class.call(params).channel

            expect(result.channel.id).to eq(existing_channel.id)
          end
        end

        context "when theres also a group channel with same users" do
          let(:target_usernames) { [user_1.username] }

          it "returns the non group existing channel" do
            group_channel = described_class.call(params.merge(name: "cats")).channel
            channel = described_class.call(params).channel

            expect(result.channel.id).to_not eq(group_channel.id)
            expect(result.channel.id).to eq(channel.id)
          end
        end
      end

      context "when a name is given" do
        let(:name) { "Monkey Island" }

        it "sets it as the channel name" do
          expect(result.channel.name).to eq(name)
        end
      end
    end

    context "when target_usernames exceeds chat_max_direct_message_users" do
      before { SiteSetting.chat_max_direct_message_users = 1 }

      it { is_expected.to fail_a_policy(:satisfies_dms_max_users_limit) }
    end

    context "when the current user cannot make direct messages" do
      fab!(:current_user) { Fabricate(:user) }

      before { SiteSetting.direct_message_enabled_groups = Fabricate(:group).id }

      it { is_expected.to fail_a_policy(:can_create_direct_message) }
    end

    context "when the plugin modifier returns false" do
      it "fails a policy" do
        modifier_block = Proc.new { false }
        plugin_instance = Plugin::Instance.new
        plugin_instance.register_modifier(:chat_can_create_direct_message_channel, &modifier_block)

        expect(result).to fail_a_policy(:can_create_direct_message)
      ensure
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :chat_can_create_direct_message_channel,
          &modifier_block
        )
      end
    end

    context "when the actor is not allowing anyone to message them" do
      before { current_user.user_option.update!(allow_private_messages: false) }

      it { is_expected.to fail_a_policy(:actor_allows_dms) }
    end

    context "when one of the target users is ignoring the current user" do
      before do
        IgnoredUser.create!(user: user_1, ignored_user: current_user, expiring_at: 1.day.from_now)
      end

      it { is_expected.to fail_a_policy(:targets_allow_dms_from_user) }
    end

    context "when one of the target users is muting the current user" do
      before { MutedUser.create!(user: user_1, muted_user: current_user) }

      it { is_expected.to fail_a_policy(:targets_allow_dms_from_user) }
    end

    context "when one of the target users is disallowing messages" do
      before { user_1.user_option.update!(allow_private_messages: false) }

      it { is_expected.to fail_a_policy(:targets_allow_dms_from_user) }
    end

    context "when the current user is allowing messages from all but one of the target users" do
      before do
        current_user.user_option.update!(enable_allowed_pm_users: true)
        AllowedPmUser.create!(user: current_user, allowed_pm_user: user_2)
      end

      it { is_expected.to fail_a_policy(:targets_allow_dms_from_user) }
    end

    context "when the current user is ignoring one of the target users" do
      before do
        IgnoredUser.create!(user: current_user, ignored_user: user_1, expiring_at: 1.day.from_now)
      end

      it { is_expected.to fail_a_policy(:targets_allow_dms_from_user) }
    end

    context "when the current user is muting one of the target users" do
      before { MutedUser.create!(user: current_user, muted_user: user_1) }

      it { is_expected.to fail_a_policy(:targets_allow_dms_from_user) }
    end
  end
end
