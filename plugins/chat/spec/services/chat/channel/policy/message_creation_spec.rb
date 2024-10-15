# frozen_string_literal: true

RSpec.describe Chat::Channel::Policy::MessageCreation do
  subject(:policy) { described_class.new(context) }

  fab!(:user)

  let(:guardian) { user.guardian }
  let(:context) { Service::Base::Context.build(channel: channel, guardian: guardian) }

  describe "#call" do
    subject(:result) { policy.call }

    context "when channel is a direct message one" do
      fab!(:channel) { Fabricate(:direct_message_channel) }

      context "when user can't create a message in this channel" do
        before { channel.closed!(Discourse.system_user) }

        context "when user can't create direct messages" do
          it "returns false" do
            expect(result).to be_falsey
          end
        end

        context "when user can create direct messages" do
          before { user.groups << Group.find(Group::AUTO_GROUPS[:trust_level_1]) }

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
    end

    context "when channel is a category one" do
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
      fab!(:channel) { Fabricate(:direct_message_channel) }

      it "returns a message related to direct messages" do
        expect(reason).to eq(I18n.t("chat.errors.user_cannot_send_direct_messages"))
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
