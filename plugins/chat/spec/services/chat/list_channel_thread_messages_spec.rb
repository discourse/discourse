# frozen_string_literal: true

RSpec.describe Chat::ListChannelThreadMessages do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:thread_id) }
    it do
      is_expected.to validate_inclusion_of(:direction).in_array(
        Chat::MessagesQuery::VALID_DIRECTIONS,
      ).allow_nil
    end
    it do
      is_expected.to allow_values(Chat::MessagesQuery::MAX_PAGE_SIZE, 1, "1", nil).for(:page_size)
    end
    it { is_expected.not_to allow_values(Chat::MessagesQuery::MAX_PAGE_SIZE + 1).for(:page_size) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:thread) { Fabricate(:chat_thread, channel: Fabricate(:chat_channel)) }

    let(:guardian) { Guardian.new(user) }
    let(:thread_id) { thread.id }
    let(:optional_params) { {} }
    let(:params) { { thread_id: }.merge(optional_params) }
    let(:dependencies) { { guardian: } }

    before { thread.channel.add(user) }

    context "when contract" do
      context "when thread_id is not present" do
        let(:thread_id) { nil }

        it { is_expected.to fail_a_contract }
      end
    end

    context "when fetch_thread" do
      context "when thread doesn’t exist" do
        let(:thread_id) { -1 }

        it { is_expected.to fail_to_find_a_model(:thread) }
      end

      context "when thread exists" do
        it { is_expected.to run_successfully }

        it "finds the correct channel" do
          expect(result.thread).to eq(thread)
        end
      end
    end

    context "when can_view_thread" do
      context "when channel is private" do
        fab!(:thread) { Fabricate(:chat_thread, channel: Fabricate(:private_category_channel)) }

        it { is_expected.to fail_a_policy(:can_view_thread) }

        context "with system user" do
          fab!(:user) { Discourse.system_user }

          it { is_expected.to run_successfully }
        end
      end
    end

    context "when determine_target_message_id" do
      let(:optional_params) { { fetch_from_last_message: true } }

      context "when fetch_from_last_message is true" do
        it "sets target_message_id to last thread message id" do
          expect(result.target_message_id).to eq(thread.chat_messages.last.id)
        end
      end

      context "when fetch_from_first_message is true" do
        it "sets target_message_id to first thread message id" do
          expect(result.target_message_id).to eq(thread.chat_messages.first.id)
        end
      end

      context "when fetch_from_last_read is true" do
        let(:optional_params) { { fetch_from_last_read: true } }

        before do
          thread.add(user)
          thread.membership_for(guardian.user).update!(last_read_message_id: 1)
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
        fab!(:target_message) do
          Fabricate(:chat_message, chat_channel: thread.channel, thread: thread)
        end
        let(:optional_params) { { target_message_id: target_message.id } }

        it { is_expected.to run_successfully }
      end

      context "when target message is trashed" do
        fab!(:target_message) do
          Fabricate(:chat_message, chat_channel: thread.channel, thread: thread)
        end
        let(:optional_params) { { target_message_id: target_message.id } }

        before { target_message.trash! }

        context "when user is regular" do
          it { is_expected.to fail_a_policy(:target_message_exists) }
        end

        context "when user is the message creator" do
          fab!(:target_message) do
            Fabricate(:chat_message, chat_channel: thread.channel, thread: thread, user: user)
          end

          it { is_expected.to run_successfully }
        end

        context "when user is admin" do
          fab!(:user) { Fabricate(:admin) }

          it { is_expected.to run_successfully }
        end
      end
    end

    context "when fetch_messages" do
      context "with not params" do
        fab!(:messages) do
          Fabricate.times(20, :chat_message, chat_channel: thread.channel, thread: thread)
        end

        it "returns messages" do
          expect(result.can_load_more_past).to eq(false)
          expect(result.can_load_more_future).to eq(false)
          expect(result.messages).to contain_exactly(thread.original_message, *messages)
        end
      end

      context "when target_date is provided" do
        fab!(:past_message) do
          Fabricate(
            :chat_message,
            chat_channel: thread.channel,
            thread: thread,
            created_at: 1.days.from_now,
          )
        end
        fab!(:future_message) do
          Fabricate(
            :chat_message,
            chat_channel: thread.channel,
            thread: thread,
            created_at: 3.days.from_now,
          )
        end

        let(:optional_params) { { target_date: 2.days.ago } }

        it "includes past and future messages" do
          expect(result.messages).to eq([thread.original_message, past_message, future_message])
        end
      end
    end
  end
end
