# frozen_string_literal: true

RSpec.describe Chat::Thread::Policy::MessageExistence do
  subject(:policy) { described_class.new(context) }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:thread, :chat_thread)

  let(:guardian) { user.guardian }
  let(:context) { Service::Base::Context.build(thread:, guardian:, target_message_id:) }

  describe "#call" do
    subject(:result) { policy.call }

    context "when 'target_message_id' is not provided" do
      let(:target_message_id) { nil }

      it { is_expected.to be true }
    end

    context "when target message does not exist" do
      let(:target_message_id) { -1 }

      it { is_expected.to be false }
    end

    context "when target message exists" do
      fab!(:message) { Fabricate(:chat_message, chat_channel: thread.channel, user:, thread:) }

      let(:target_message_id) { message.id }

      context "when target message is not trashed" do
        it { is_expected.to be true }
      end

      context "when target message is trashed and belongs to the guardian" do
        before { message.trash! }

        it { is_expected.to be true }
      end

      context "when target message is trashed, belongs to another user, and guardian is staff" do
        fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }

        let(:guardian) { Discourse.system_user.guardian }

        before do
          message.trash!
          message.update!(user: other_user)
        end

        it { is_expected.to be true }
      end

      context "when target message is trashed, belongs to another user, and guardian is not staff" do
        fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }

        before do
          message.trash!
          message.update!(user: other_user)
        end

        it { is_expected.to be false }
      end
    end
  end
end
