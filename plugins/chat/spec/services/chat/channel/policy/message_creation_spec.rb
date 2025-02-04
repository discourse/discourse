# frozen_string_literal: true

RSpec.describe Chat::Channel::Policy::MessageCreation do
  subject(:policy) { described_class.new(context) }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:guardian) { user.guardian }
  let(:context) { Service::Base::Context.build(channel: channel, guardian: guardian) }

  describe "#call" do
    subject(:result) { policy.call }

    context "when direct message channel" do
      fab!(:channel) { Fabricate(:direct_message_channel, users: [user, Fabricate(:user)]) }

      before do
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
        SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone]
      end

      context "when user can't create a message in this channel" do
        before { channel.closed!(Discourse.system_user) }

        context "when user can't create direct messages" do
          it "returns false" do
            expect(result).to be_falsey
          end
        end

        context "when admin can create direct messages" do
          before { user.grant_admin! }

          it "returns true" do
            expect(result).to be_truthy
          end
        end
      end

      context "when user can create a message in this channel" do
        it "returns true" do
          expect(result).to be_truthy
        end
      end

      context "when user can't send direct messages to the channel" do
        before { channel.chatable.users.delete(user) }

        it "returns false" do
          expect(result).to be_falsey
        end
      end

      context "when user can send direct messages to the channel" do
        it "returns true" do
          expect(result).to be_truthy
        end
      end
    end

    context "when category channel" do
      fab!(:channel) { Fabricate(:chat_channel) }

      context "when user can't create a message in this channel" do
        before { channel.closed!(Discourse.system_user) }

        it "returns false" do
          expect(result).to be_falsey
        end
      end

      context "when user can create a message in this channel" do
        it "returns true" do
          expect(result).to be_truthy
        end
      end
    end
  end

  describe "#reason" do
    subject(:reason) { policy.reason }

    context "when channel is a direct message one" do
      fab!(:other_user) { Fabricate(:user) }
      fab!(:channel) { Fabricate(:direct_message_channel, users: [user, other_user]) }

      before { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone] }

      it "returns a message related to direct messages" do
        expect(reason).to eq(I18n.t("chat.errors.user_cannot_send_direct_messages"))
      end

      context "when sender does not allow direct messages" do
        before { user.user_option.update!(allow_private_messages: false) }

        it "returns a proper message" do
          expect(reason).to eq(I18n.t("chat.errors.actor_disallowed_dms"))
        end
      end

      context "when sender is not able to send messages to the channel" do
        before { channel.chatable.users.delete(user) }

        it "returns a proper message" do
          expect(reason).to eq(I18n.t("chat.errors.user_cannot_send_direct_messages"))
        end
      end

      context "when sender is muting the target user" do
        before { MutedUser.create!(user: user, muted_user: other_user) }

        it "returns a proper message" do
          expect(reason).to eq(
            I18n.t("chat.errors.actor_muting_target_user", username: other_user.username),
          )
        end
      end

      context "when sender is ignoring the target user" do
        before do
          IgnoredUser.create!(user: user, ignored_user: other_user, expiring_at: 1.day.from_now)
        end

        it "returns a proper message" do
          expect(reason).to eq(
            I18n.t("chat.errors.actor_ignoring_target_user", username: other_user.username),
          )
        end
      end

      context "when recipient is not able to chat" do
        before { other_user.user_option.update!(chat_enabled: false) }

        it "returns a proper message" do
          expect(reason).to eq(I18n.t("chat.errors.not_reachable", username: other_user.username))
        end
      end

      context "when sender is muted by the recipient" do
        before { MutedUser.create!(user: other_user, muted_user: user) }

        it "returns a proper message" do
          expect(reason).to eq(
            I18n.t("chat.errors.not_accepting_dms", username: other_user.username),
          )
        end
      end

      context "when sender is ignored by the recipient" do
        before do
          IgnoredUser.create!(user: other_user, ignored_user: user, expiring_at: 1.day.from_now)
        end

        it "returns a proper message" do
          expect(reason).to eq(
            I18n.t("chat.errors.not_accepting_dms", username: other_user.username),
          )
        end
      end
    end

    context "when channel is a category one" do
      let!(:channel) { Fabricate(:chat_channel, status: status) }

      context "when channel is closed" do
        let(:status) { :closed }

        it "returns a proper message" do
          expect(reason).to eq(I18n.t("chat.errors.channel_new_message_disallowed.closed"))
        end
      end

      context "when channel is archived" do
        let(:status) { :archived }

        it "returns a proper message" do
          expect(reason).to eq(I18n.t("chat.errors.channel_new_message_disallowed.archived"))
        end
      end

      context "when channel is read-only" do
        let(:status) { :read_only }

        it "returns a proper message" do
          expect(reason).to eq(I18n.t("chat.errors.channel_new_message_disallowed.read_only"))
        end
      end
    end
  end
end
