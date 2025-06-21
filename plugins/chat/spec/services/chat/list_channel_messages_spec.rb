# frozen_string_literal: true

RSpec.describe Chat::ListChannelMessages do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:channel_id) }
    it { is_expected.to allow_values(1, Chat::MessagesQuery::MAX_PAGE_SIZE, nil).for(:page_size) }
    it do
      is_expected.not_to allow_values(0, Chat::MessagesQuery::MAX_PAGE_SIZE + 1).for(:page_size)
    end
    it do
      is_expected.to validate_inclusion_of(:direction).in_array(
        Chat::MessagesQuery::VALID_DIRECTIONS,
      ).allow_nil
    end

    describe "#page_size" do
      let(:contract) { described_class.new }

      context "when page_size is not set" do
        it "defaults to MAX_PAGE_SIZE" do
          contract.validate
          expect(contract.page_size).to eq(Chat::MessagesQuery::MAX_PAGE_SIZE)
        end
      end

      context "when page_size is set to nil" do
        before { contract.page_size = nil }

        it "defaults to MAX_PAGE_SIZE" do
          contract.validate
          expect(contract.page_size).to eq(Chat::MessagesQuery::MAX_PAGE_SIZE)
        end
      end

      context "when page_size is set" do
        before { contract.page_size = 5 }

        it "does not change the value" do
          contract.validate
          expect(contract.page_size).to eq(5)
        end
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }

    let(:guardian) { Guardian.new(user) }
    let(:channel_id) { channel.id }
    let(:optional_params) { {} }
    let(:params) { { channel_id:, **optional_params } }
    let(:dependencies) { { guardian: } }

    before { channel.add(user) }

    context "when data is not valid" do
      let(:channel_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when channel doesn’t exist" do
      let(:channel_id) { -1 }

      it { is_expected.to fail_to_find_a_model(:channel) }
    end

    context "when target message is not found" do
      let(:optional_params) { { target_message_id: -1 } }

      it { is_expected.to fail_a_policy(:target_message_exists) }
    end

    context "when everything is ok" do
      fab!(:thread) { Fabricate(:chat_thread, channel:) }
      fab!(:messages) do
        [thread.original_message, *Fabricate.times(20, :chat_message, chat_channel: channel)]
      end

      let(:tracking) { double }
      let(:thread_ids) { [thread.id] }

      before do
        thread.add(user)
        allow(Chat::TrackingStateReportQuery).to receive(:call).with(
          guardian:,
          thread_ids:,
          include_threads: true,
        ).and_return(tracking)
      end

      it { is_expected.to run_successfully }

      it "finds the correct channel" do
        expect(result.channel).to eq(channel)
      end

      it "finds the correct membership" do
        expect(result.membership).to eq(channel.membership_for(user))
      end

      context "when fetch_from_last_read is true" do
        let(:optional_params) { { fetch_from_last_read: true } }

        before do
          channel.add(user)
          channel.membership_for(user).update!(last_read_message: messages.second)
        end

        it "sets target_message to last_read_message_id" do
          expect(result.metadata[:target_message]).to eq(messages.second)
        end
      end

      it "returns messages" do
        expect(result).to have_attributes(
          metadata: a_hash_including(can_load_more_future: false, can_load_more_past: false),
          messages:,
        )
      end

      context "when target_date is provided" do
        fab!(:past_message) do
          Fabricate(:chat_message, chat_channel: channel, created_at: 3.days.ago)
        end
        fab!(:future_message) do
          Fabricate(:chat_message, chat_channel: channel, created_at: 1.days.ago)
        end

        let(:optional_params) { { target_date: 2.days.ago } }

        it "includes past and future messages" do
          expect(result.messages).to include(past_message, future_message)
        end
      end

      it "returns tracking" do
        expect(result.tracking).to eq(tracking)
      end

      it "updates the last viewed at" do
        expect { result }.to change { channel.membership_for(user).last_viewed_at }.to be_within(
          1.second,
        ).of(Time.zone.now)
      end

      it "updates the custom field" do
        expect { result }.to change { user.custom_fields[Chat::LAST_CHAT_CHANNEL_ID] }.from(nil).to(
          channel.id,
        )
      end

      context "when custom field was already set" do
        let(:field) { UserCustomField.find_by(name: Chat::LAST_CHAT_CHANNEL_ID, user_id: user.id) }

        before { user.upsert_custom_fields(::Chat::LAST_CHAT_CHANNEL_ID => channel.id) }

        it "doesn’t update the custom field" do
          expect { result }.to_not change { field.reload.updated_at }
        end
      end
    end
  end
end
