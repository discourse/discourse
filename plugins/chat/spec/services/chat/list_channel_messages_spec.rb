# frozen_string_literal: true

RSpec.describe Chat::ListChannelMessages do
  subject(:result) { described_class.call(params:, **dependencies) }

  fab!(:user)
  fab!(:channel) { Fabricate(:chat_channel) }

  let(:guardian) { Guardian.new(user) }
  let(:channel_id) { channel.id }
  let(:optional_params) { {} }
  let(:params) { { channel_id: }.merge(optional_params) }
  let(:dependencies) { { guardian: } }

  before { channel.add(user) }

  context "when contract" do
    context "when channel_id is not present" do
      let(:channel_id) { nil }

      it { is_expected.to fail_a_contract }
    end
  end

  context "when fetch_channel" do
    context "when channel doesn’t exist" do
      let(:channel_id) { -1 }

      it { is_expected.to fail_to_find_a_model(:channel) }
    end

    context "when channel exists" do
      it { is_expected.to run_successfully }

      it "finds the correct channel" do
        expect(result.channel).to eq(channel)
      end
    end
  end

  context "when fetch_eventual_membership" do
    context "when user has membership" do
      it { is_expected.to run_successfully }

      it "finds the correct membership" do
        expect(result.membership).to eq(channel.membership_for(user))
      end
    end

    context "when user has no membership" do
      before { channel.membership_for(user).destroy! }

      it { is_expected.to run_successfully }

      it "finds no membership" do
        expect(result.membership).to be_blank
      end
    end
  end

  context "when enabled_threads?" do
    context "when channel threading is disabled" do
      before { channel.update!(threading_enabled: false) }

      it "marks threads as disabled" do
        expect(result.enabled_threads).to eq(false)
      end
    end

    context "when channel and site setting are enabling threading" do
      before { channel.update!(threading_enabled: true) }

      it "marks threads as enabled" do
        expect(result.enabled_threads).to eq(true)
      end
    end
  end

  context "when determine_target_message_id" do
    context "when fetch_from_last_read is true" do
      let(:optional_params) { { fetch_from_last_read: true } }

      before do
        channel.add(user)
        channel.membership_for(user).update!(last_read_message_id: 1)
      end

      it "sets target_message_id to last_read_message_id" do
        expect(result.target_message_id).to eq(1)
      end
    end
  end

  context "when target_message_exists" do
    context "when no target_message_id is given" do
      it { is_expected.to run_successfully }
    end

    context "when target message is not found" do
      let(:optional_params) { { target_message_id: -1 } }

      it { is_expected.to fail_a_policy(:target_message_exists) }
    end

    context "when target message is found" do
      fab!(:target_message) { Fabricate(:chat_message, chat_channel: channel) }
      let(:optional_params) { { target_message_id: target_message.id } }

      it { is_expected.to run_successfully }
    end

    context "when target message is trashed" do
      fab!(:target_message) { Fabricate(:chat_message, chat_channel: channel) }
      let(:optional_params) { { target_message_id: target_message.id } }

      before { target_message.trash! }

      context "when user is regular" do
        it "nullifies target_message_id" do
          expect(result.target_message_id).to be_blank
        end
      end

      context "when user is the message creator" do
        fab!(:target_message) { Fabricate(:chat_message, chat_channel: channel, user: user) }

        it { is_expected.to run_successfully }
      end

      context "when user is admin" do
        fab!(:user) { Fabricate(:admin) }

        it { is_expected.to run_successfully }
      end
    end
  end

  context "when fetch_messages" do
    context "with no params" do
      fab!(:messages) { Fabricate.times(20, :chat_message, chat_channel: channel) }

      it { is_expected.to be_a_success }

      it "returns messages" do
        expect(result.can_load_more_past).to eq(false)
        expect(result.can_load_more_future).to eq(false)
        expect(result.messages).to contain_exactly(*messages)
      end
    end

    context "when target_date is provided" do
      fab!(:past_message) do
        Fabricate(:chat_message, chat_channel: channel, created_at: 3.days.ago)
      end
      fab!(:future_message) do
        Fabricate(:chat_message, chat_channel: channel, created_at: 1.days.ago)
      end

      let(:optional_params) { { target_date: 2.days.ago } }

      it { is_expected.to be_a_success }

      it "includes past and future messages" do
        expect(result.messages).to eq([past_message, future_message])
      end
    end
  end

  context "when fetch_tracking" do
    context "when threads are disabled" do
      fab!(:thread_1) { Fabricate(:chat_thread, channel: channel) }

      before do
        channel.update!(threading_enabled: false)
        thread_1.add(user)
      end

      it { is_expected.to be_a_success }

      it "returns tracking" do
        Fabricate(:chat_message, chat_channel: channel, thread: thread_1)

        expect(result.tracking.thread_tracking).to eq(
          {
            thread_1.id => {
              channel_id: channel.id,
              mention_count: 0,
              unread_count: 0,
              watched_threads_unread_count: 0,
            },
          },
        )
      end

      context "when thread is forced" do
        before { thread_1.update!(force: true) }

        it { is_expected.to be_a_success }

        it "returns tracking" do
          Fabricate(:chat_message, chat_channel: channel, thread: thread_1)

          expect(result.tracking.thread_tracking).to eq(
            {
              thread_1.id => {
                channel_id: channel.id,
                mention_count: 0,
                unread_count: 1,
                watched_threads_unread_count: 0,
              },
            },
          )
        end
      end
    end

    context "when threads are enabled" do
      fab!(:thread_1) { Fabricate(:chat_thread, channel: channel) }

      before do
        channel.update!(threading_enabled: true)
        thread_1.add(user)
      end

      it { is_expected.to be_a_success }

      it "returns tracking" do
        Fabricate(:chat_message, chat_channel: channel, thread: thread_1)

        expect(result.tracking.channel_tracking).to eq({})
        expect(result.tracking.thread_tracking).to eq(
          {
            thread_1.id => {
              channel_id: channel.id,
              mention_count: 0,
              unread_count: 1,
              watched_threads_unread_count: 0,
            },
          },
        )
      end
    end
  end

  context "when update_membership_last_viewed_at" do
    it "updates the last viewed at" do
      expect { result }.to change { channel.membership_for(user).last_viewed_at }.to be_within(
        1.second,
      ).of(Time.zone.now)
    end
  end

  context "when update_user_last_channel" do
    it "updates the custom field" do
      expect { result }.to change { user.custom_fields[Chat::LAST_CHAT_CHANNEL_ID] }.from(nil).to(
        channel.id,
      )
    end

    it "doesn’t update the custom field when it was already set to this value" do
      user.upsert_custom_fields(::Chat::LAST_CHAT_CHANNEL_ID => channel.id)
      field = UserCustomField.find_by(name: Chat::LAST_CHAT_CHANNEL_ID, user_id: user.id)

      expect { result }.to_not change { field.reload.updated_at }
    end
  end
end
