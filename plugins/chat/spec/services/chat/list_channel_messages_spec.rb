# frozen_string_literal: true

RSpec.describe Chat::ListChannelMessages do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:channel_id) }
    it do
      is_expected.to validate_numericality_of(:page_size)
        .is_less_than_or_equal_to(Chat::MessagesQuery::MAX_PAGE_SIZE)
        .only_integer
        .allow_nil
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
    fab!(:channel) { Fabricate(:chat_channel) }

    let(:guardian) { Guardian.new(user) }
    let(:channel_id) { channel.id }
    let(:optional_params) { {} }
    let(:params) { { channel_id: }.merge(optional_params) }
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
      fab!(:messages) { Fabricate.times(20, :chat_message, chat_channel: channel) }

      it { is_expected.to run_successfully }

      it "finds the correct channel" do
        expect(result.channel).to eq(channel)
      end

      context "when user has membership" do
        it "finds the correct membership" do
          expect(result.membership).to eq(channel.membership_for(user))
        end
      end

      context "when user has no membership" do
        before { channel.membership_for(user).destroy! }

        it "finds no membership" do
          expect(result.membership).to be_blank
        end
      end

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

      context "when target message is trashed" do
        fab!(:target_message) { Fabricate(:chat_message, chat_channel: channel) }
        let(:optional_params) { { target_message_id: target_message.id } }

        before { target_message.trash! }

        context "when user is regular" do
          it "nullifies target_message_id" do
            expect(result.target_message_id).to be_blank
          end
        end
      end

      it "returns messages" do
        expect(result).to have_attributes(
          can_load_more_past: false,
          can_load_more_future: false,
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

      context "when threads are disabled" do
        fab!(:thread_1) { Fabricate(:chat_thread, channel:) }

        before do
          channel.update!(threading_enabled: false)
          thread_1.add(user)
          Fabricate(:chat_message, chat_channel: channel, thread: thread_1)
        end

        it "returns tracking" do
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
          before do
            thread_1.update!(force: true)
            Fabricate(:chat_message, chat_channel: channel, thread: thread_1)
          end

          it "returns tracking" do
            expect(result.tracking.thread_tracking).to eq(
              {
                thread_1.id => {
                  channel_id: channel.id,
                  mention_count: 0,
                  unread_count: 2,
                  watched_threads_unread_count: 0,
                },
              },
            )
          end
        end
      end

      context "when threads are enabled" do
        fab!(:thread_1) { Fabricate(:chat_thread, channel:) }

        before do
          channel.update!(threading_enabled: true)
          thread_1.add(user)
          Fabricate(:chat_message, chat_channel: channel, thread: thread_1)
        end

        it "returns tracking" do
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

      it "doesn’t update the custom field when it was already set to this value" do
        user.upsert_custom_fields(::Chat::LAST_CHAT_CHANNEL_ID => channel.id)
        field = UserCustomField.find_by(name: Chat::LAST_CHAT_CHANNEL_ID, user_id: user.id)

        expect { result }.to_not change { field.reload.updated_at }
      end
    end
  end
end
