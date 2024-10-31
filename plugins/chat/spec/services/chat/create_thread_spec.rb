# frozen_string_literal: true

RSpec.describe Chat::CreateThread do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :channel_id }
    it { is_expected.to validate_presence_of :original_message_id }
    it { is_expected.to validate_length_of(:title).is_at_most(Chat::Thread::MAX_TITLE_LENGTH) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:another_user) { Fabricate(:user) }
    fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }
    fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [current_user, another_user]) }
    fab!(:dm_message) { Fabricate(:chat_message, chat_channel: dm_channel) }

    let(:guardian) { Guardian.new(current_user) }
    let(:title) { nil }
    let(:params) { { original_message_id: message_1.id, channel_id: channel_1.id, title: } }
    let(:dependencies) { { guardian: } }

    context "when all steps pass" do
      it { is_expected.to run_successfully }

      it "creates a thread" do
        result
        expect(result.thread).to be_persisted
      end

      it "associates the original message to the thread" do
        expect {
          result
          message_1.reload
        }.to change { message_1.thread_id }.from(nil).to(result.thread.id)
      end

      it "fetches the membership" do
        result
        expect(result.membership).to eq(result.thread.membership_for(current_user))
      end

      it "publishes a `thread_created` MessageBus event for public channels" do
        message = MessageBus.track_publish("/chat/#{channel_1.id}") { result }.first
        expect(message.data["type"]).to eq("thread_created")
      end

      it "publishes a `thread_created` MessageBus event for DM channels" do
        params[:channel_id] = dm_channel.id
        params[:original_message_id] = dm_message.id
        params[:guardian] = Guardian.new(another_user)
        message = MessageBus.track_publish("/chat/#{dm_channel.id}") { result }.first

        expect(message.data["type"]).to eq("thread_created")
      end

      it "triggers a discourse event `chat_thread_created`" do
        event = DiscourseEvent.track_events(:chat_thread_created) { result }.first

        expect(event[:params][0]).to eq(result.thread)
      end

      it "sets the title when existing" do
        params[:title] = "Restaurant for Saturday"
        result
        expect(result.thread.title).to eq(params[:title])
      end
    end

    context "when params are not valid" do
      before { params.delete(:original_message_id) }

      it { is_expected.to fail_a_contract }
    end

    context "when original message is not found" do
      fab!(:channel_2) { Fabricate(:chat_channel, threading_enabled: true) }

      before { params[:channel_id] = channel_2.id }

      it { is_expected.to fail_to_find_a_model(:original_message) }
    end

    context "when original message is not found" do
      before { message_1.destroy! }

      it { is_expected.to fail_to_find_a_model(:original_message) }
    end

    context "when user cannot see channel" do
      fab!(:private_channel_1) { Fabricate(:private_category_channel, group: Fabricate(:group)) }

      before { params[:channel_id] = private_channel_1.id }

      it { is_expected.to fail_a_policy(:can_view_channel) }
    end

    context "when threading is not enabled for the channel" do
      before { channel_1.update!(threading_enabled: false) }

      it { is_expected.to fail_a_policy(:threading_enabled_for_channel) }
    end

    context "when a thread is already present" do
      before do
        Chat::CreateThread.call(
          guardian: current_user.guardian,
          params: {
            original_message_id: message_1.id,
            channel_id: channel_1.id,
          },
        )
      end

      it "uses the existing thread" do
        expect { result }.not_to change { Chat::Thread.count }
      end
    end
  end
end
