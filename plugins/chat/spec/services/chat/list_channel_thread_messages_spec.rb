# frozen_string_literal: true

RSpec.describe Chat::ListChannelThreadMessages do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(options:) }

    let(:options) { OpenStruct.new(max_page_size: Chat::MessagesQuery::MAX_PAGE_SIZE) }

    it { is_expected.to validate_presence_of(:thread_id) }
    it { is_expected.to allow_values(1, options.max_page_size, nil).for(:page_size) }
    it { is_expected.not_to allow_values(0).for(:page_size) }
    it do
      is_expected.to validate_inclusion_of(:direction).in_array(
        Chat::MessagesQuery::VALID_DIRECTIONS,
      ).allow_nil
    end

    describe "#page_size" do
      context "when page_size is not set" do
        it "defaults to options.max_page_size" do
          contract.validate
          expect(contract.page_size).to eq(options.max_page_size)
        end
      end

      context "when page_size is set to nil" do
        before { contract.page_size = nil }

        it "defaults to options.max_page_size" do
          contract.validate
          expect(contract.page_size).to eq(options.max_page_size)
        end
      end

      context "when page_size is set" do
        context "when page_size is greater than max_page_size" do
          before { contract.page_size = options.max_page_size + 1 }

          it "sets page_size to options.max_page_size" do
            contract.validate
            expect(contract.page_size).to eq(options.max_page_size)
          end
        end

        context "when page_size is lesser than max_page_size" do
          before { contract.page_size = 5 }

          it "does not change the value" do
            contract.validate
            expect(contract.page_size).to eq(5)
          end
        end
      end
    end

    describe "#include_target_message_id?" do
      alias_matcher :include_target_message_id, :be_include_target_message_id

      subject(:contract) do
        described_class.new(options:, fetch_from_first_message:, fetch_from_last_message:)
      end

      let(:fetch_from_first_message) { false }
      let(:fetch_from_last_message) { false }

      context "when 'fetch_from_first_message' is true" do
        let(:fetch_from_first_message) { true }

        it { is_expected.to include_target_message_id }
      end

      context "when 'fetch_from_last_message' is true" do
        let(:fetch_from_last_message) { true }

        it { is_expected.to include_target_message_id }
      end

      context "when both 'fecth_from_first_message' and 'fetch_from_last_message' are false" do
        it { is_expected.not_to include_target_message_id }
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:thread, :chat_thread)

    let(:guardian) { user.guardian }
    let(:thread_id) { thread.id }
    let(:optional_params) { {} }
    let(:params) { { thread_id:, **optional_params } }
    let(:dependencies) { { guardian: } }

    before { thread.channel.add(user) }

    context "when data is not valid" do
      let(:thread_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when thread doesn’t exist" do
      let(:thread_id) { -1 }

      it { is_expected.to fail_to_find_a_model(:thread) }
    end

    context "when user cannot view the thread" do
      fab!(:thread) { Fabricate(:chat_thread, channel: Fabricate(:private_category_channel)) }

      it { is_expected.to fail_a_policy(:can_view_thread) }
    end

    context "when target message is not found" do
      let(:optional_params) { { target_message_id: -1 } }

      it { is_expected.to fail_a_policy(:target_message_exists) }
    end

    context "when everything is ok" do
      fab!(:messages) { Fabricate.times(20, :chat_message, chat_channel: thread.channel, thread:) }

      it { is_expected.to run_successfully }

      it "finds the correct thread" do
        expect(result.thread).to eq(thread)
      end

      it "finds the correct membership" do
        expect(result.membership).to eq(thread.membership_for(user))
      end

      it "returns messages" do
        expect(result).to have_attributes(
          metadata: a_hash_including(can_load_more_future: false, can_load_more_past: false),
          messages: [thread.original_message, *messages],
        )
      end

      context "when target_date is provided" do
        fab!(:past_message) do
          Fabricate(
            :chat_message,
            chat_channel: thread.channel,
            created_at: 1.day.from_now,
            thread:,
          )
        end
        fab!(:future_message) do
          Fabricate(
            :chat_message,
            chat_channel: thread.channel,
            created_at: 3.days.from_now,
            thread:,
          )
        end

        let(:optional_params) { { target_date: 2.days.ago } }

        it "includes past and future messages" do
          expect(result.messages).to include(past_message, future_message)
        end
      end

      context "when fetch_from_last_message is true" do
        let(:optional_params) { { fetch_from_last_message: true } }

        before { thread.update!(last_message: messages.second) }

        it "sets target_message to last thread message id" do
          expect(result.metadata[:target_message]).to eq(messages.second)
        end
      end

      context "when fetch_from_first_message is true" do
        let(:optional_params) { { fetch_from_first_message: true } }

        it "sets target_message to first thread message id" do
          expect(result.metadata[:target_message]).to eq(thread.original_message)
        end
      end

      context "when fetch_from_last_read is true" do
        let(:optional_params) { { fetch_from_last_read: true } }

        before do
          thread.add(user)
          thread.membership_for(guardian.user).update!(last_read_message: messages.third)
        end

        it "sets target_message to last_read_message_id" do
          expect(result.metadata[:target_message]).to eq(messages.third)
        end
      end
    end
  end
end
