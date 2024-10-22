# frozen_string_literal: true

RSpec.describe Chat::UpdateThread do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :thread_id }
    it { is_expected.to validate_length_of(:title).is_at_most(Chat::Thread::MAX_TITLE_LENGTH) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:private_channel) { Fabricate(:private_category_channel, group: Fabricate(:group)) }
    fab!(:thread) { Fabricate(:chat_thread, channel: channel, original_message_user: current_user) }
    fab!(:other_thread) { Fabricate(:chat_thread) }

    let(:guardian) { Guardian.new(current_user) }
    let(:title) { "some new title :D" }
    let(:params) { { guardian: guardian, thread_id: thread.id, title: title } }

    context "when all steps pass" do
      it { is_expected.to run_successfully }

      it "updates the title of the thread" do
        result
        expect(thread.reload.title).to eq(title)
      end

      it "publishes a MessageBus message" do
        message =
          MessageBus
            .track_publish(Chat::Publisher.root_message_bus_channel(thread.channel_id)) { result }
            .first

        expect(message.data["type"]).to eq("update_thread_original_message")
      end
    end

    context "when params are not valid" do
      before { params.delete(:thread_id) }

      it { is_expected.to fail_a_contract }
    end

    context "when thread is not found" do
      before { thread.destroy! }

      it { is_expected.to fail_to_find_a_model(:thread) }
    end

    context "when user cannot see channel" do
      before { thread.update!(channel: private_channel) }

      it { is_expected.to fail_a_policy(:can_view_channel) }
    end

    context "when user is not the thread original message creator" do
      before { thread.update!(original_message_user: Fabricate(:user)) }

      it { is_expected.to fail_a_policy(:can_edit_thread) }
    end

    context "when user is not the thread original message creator but they are staff" do
      before do
        thread.original_message.update!(user: Fabricate(:user))
        current_user.update!(admin: true)
      end

      it { is_expected.not_to fail_a_policy(:can_edit_thread) }
    end

    context "when threading is not enabled for the channel" do
      before { channel.update!(threading_enabled: false) }

      it { is_expected.to fail_a_policy(:threading_enabled_for_channel) }
    end
  end
end
