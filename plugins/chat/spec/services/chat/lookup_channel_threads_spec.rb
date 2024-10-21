# frozen_string_literal: true

RSpec.describe ::Chat::LookupChannelThreads::Contract, type: :model do
  subject(:contract) { described_class.new(channel_id: 1) }

  it { is_expected.to validate_presence_of(:channel_id) }
  it { is_expected.to allow_values(1, 0, nil, "a").for(:limit) }
  it do
    is_expected.not_to allow_values(::Chat::LookupChannelThreads::THREADS_LIMIT + 1).for(:limit)
  end
end

RSpec.describe ::Chat::LookupChannelThreads do
  subject(:result) { described_class.call(params:, **dependencies) }

  fab!(:current_user) { Fabricate(:user) }

  let(:guardian) { Guardian.new(current_user) }
  let(:channel_id) { nil }
  let(:limit) { 10 }
  let(:offset) { 0 }
  let(:params) { { channel_id:, limit:, offset: } }
  let(:dependencies) { { guardian: } }

  describe "step - set_limit" do
    fab!(:channel_1) { Fabricate(:chat_channel) }
    let(:channel_id) { channel_1.id }

    context "when limit is not set" do
      let(:limit) { nil }

      it "defaults to a max value" do
        expect(result.limit).to eq(described_class::THREADS_LIMIT)
      end
    end

    context "when limit is over max" do
      let(:limit) { described_class::THREADS_LIMIT + 1 }

      it { is_expected.to fail_a_contract }
    end

    context "when limit is under min" do
      let(:limit) { 0 }

      it "defaults to a max value" do
        expect(result.limit).to eq(1)
      end
    end
  end

  describe "step - set_offset" do
    fab!(:channel_1) { Fabricate(:chat_channel) }
    let(:channel_id) { channel_1.id }

    context "when offset is not set" do
      let(:offset) { nil }

      it "defaults to zero" do
        expect(result.offset).to eq(0)
      end
    end

    context "when offset is under min" do
      let(:offset) { -99 }

      it "defaults to a min value" do
        expect(result.offset).to eq(0)
      end
    end
  end

  describe "model - channel" do
    context "when channel doesn’t exist" do
      let(:channel_id) { -999 }

      it { is_expected.to fail_to_find_a_model(:channel) }
    end
  end

  describe "policy - threading_enabled_for_channel" do
    context "when channel threading is disabled" do
      fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: false) }
      let(:channel_id) { channel_1.id }

      it { is_expected.to fail_a_policy(:threading_enabled_for_channel) }
    end
  end

  describe "policy - can_view_channel" do
    context "when channel threading is disabled" do
      fab!(:channel_1) { Fabricate(:private_category_channel, threading_enabled: true) }
      let(:channel_id) { channel_1.id }

      it { is_expected.to fail_a_policy(:can_view_channel) }
    end
  end

  context "when channel has no threads" do
    fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
    let(:channel_id) { channel_1.id }

    describe "model - threads" do
      it "returns an empty list of threads" do
        expect(result.threads).to eq([])
      end
    end
  end

  context "when channel has threads" do
    fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }
    fab!(:thread_2) { Fabricate(:chat_thread, channel: channel_1) }
    fab!(:thread_3) { Fabricate(:chat_thread, channel: channel_1) }

    let(:channel_id) { channel_1.id }

    before do
      [thread_1, thread_2, thread_3].each.with_index do |t, index|
        t.original_message.update!(created_at: (index + 1).weeks.ago)
        t.update!(replies_count: 2)
        t.add(current_user)
      end
    end

    describe "model - threads" do
      before { channel_1.add(current_user) }

      it { is_expected.to run_successfully }

      it "orders threads by the last reply created_at timestamp" do
        [
          [thread_1, 10.minutes.ago],
          [thread_2, 1.day.ago],
          [thread_3, 2.seconds.ago],
        ].each do |thread, created_at|
          message =
            Fabricate(
              :chat_message,
              user: current_user,
              chat_channel: channel_1,
              thread: thread,
              created_at: created_at,
            )
          thread.update!(last_message: message)
        end

        expect(result.threads.map(&:id)).to eq([thread_3.id, thread_1.id, thread_2.id])
      end

      it "sorts by unread over recency" do
        unread_message = Fabricate(:chat_message, chat_channel: channel_1, thread: thread_2)
        unread_message.update!(created_at: 2.days.ago)
        thread_2.update!(last_message: unread_message)

        expect(result.threads.map(&:id)).to eq([thread_2.id, thread_1.id, thread_3.id])
      end

      describe "when there are more threads than the limit" do
        let(:limit) { 5 }

        it "sorts very old unreads to top over recency, and sorts both unreads and other threads by recency" do
          thread_4 = Fabricate(:chat_thread, channel: channel_1)
          thread_4.update!(replies_count: 2)
          thread_5 = Fabricate(:chat_thread, channel: channel_1)
          thread_5.update!(replies_count: 2)
          thread_6 = Fabricate(:chat_thread, channel: channel_1)
          thread_6.update!(replies_count: 2)
          thread_7 = Fabricate(:chat_thread, channel: channel_1)
          thread_7.update!(replies_count: 2)

          [thread_4, thread_5, thread_6, thread_7].each do |t|
            t.add(current_user)
            t.membership_for(current_user).mark_read!
          end
          [thread_1, thread_2, thread_3].each { |t| t.membership_for(current_user).mark_read! }

          # The old unread messages.
          Fabricate(:chat_message, chat_channel: channel_1, thread: thread_7).update!(
            created_at: 2.months.ago,
          )
          Fabricate(:chat_message, chat_channel: channel_1, thread: thread_6).update!(
            created_at: 3.months.ago,
          )

          expect(result.threads.map(&:id)).to eq(
            [thread_7.id, thread_6.id, thread_5.id, thread_4.id, thread_1.id],
          )
        end
      end

      it "does not return threads where the original message is trashed" do
        thread_1.original_message.trash!

        expect(result.threads.map(&:id)).to eq([thread_2.id, thread_3.id])
      end

      it "does not return threads where the original message is deleted" do
        thread_1.original_message.destroy

        expect(result.threads.map(&:id)).to eq([thread_2.id, thread_3.id])
      end

      it "does not return threads from another channel" do
        thread_4 = Fabricate(:chat_thread)
        Fabricate(
          :chat_message,
          user: current_user,
          thread: thread_4,
          chat_channel: thread_4.channel,
          created_at: 2.seconds.ago,
        )

        expect(result.threads.map(&:id)).to eq([thread_1.id, thread_2.id, thread_3.id])
      end

      it "returns every threads of the channel, no matter the tracking notification level or membership" do
        thread_4 = Fabricate(:chat_thread, channel: channel_1)
        thread_4.update!(replies_count: 2)

        expect(result.threads.map(&:id)).to match_array(
          [thread_1.id, thread_2.id, thread_3.id, thread_4.id],
        )
      end

      it "doesnt return muted threads" do
        thread = Fabricate(:chat_thread, channel: channel_1)
        thread.add(current_user)
        thread.membership_for(current_user).update!(
          notification_level: ::Chat::UserChatThreadMembership.notification_levels[:muted],
        )

        expect(result.threads.map(&:id)).to_not include(thread.id)
      end

      it "does not count deleted messages for sort order" do
        original_last_message_id = thread_3.reload.last_message_id
        unread_message = Fabricate(:chat_message, chat_channel: channel_1, thread: thread_3)
        unread_message.update!(created_at: 2.days.ago)
        unread_message.trash!
        thread_3.reload.update!(last_message_id: original_last_message_id)

        expect(result.threads.map(&:id)).to eq([thread_1.id, thread_2.id, thread_3.id])
      end

      context "when limit param is set" do
        let(:limit) { 1 }

        it "limits the number of threads returned" do
          expect(result.threads).to contain_exactly(thread_1)
        end
      end

      context "when offset param is set" do
        let(:offset) { 1 }

        it "returns results from the offset the number of threads returned" do
          expect(result.threads).to eq([thread_2, thread_3])
        end
      end
    end

    describe "step - fetch_tracking" do
      it "returns correct threads tracking" do
        expect(result.tracking).to eq(
          ::Chat::TrackingStateReportQuery.call(
            guardian: guardian,
            thread_ids: [thread_1, thread_2, thread_3].map(&:id),
            include_threads: true,
          ).thread_tracking,
        )
      end
    end

    describe "step - fetch_memberships" do
      it "returns correct memberships" do
        expect(result.memberships).to eq(
          ::Chat::UserChatThreadMembership.where(
            thread_id: [thread_1, thread_2, thread_3].map(&:id),
            user_id: current_user.id,
          ),
        )
      end
    end

    describe "step - fetch_participants" do
      it "returns correct participants" do
        expect(result.participants).to eq(
          ::Chat::ThreadParticipantQuery.call(thread_ids: [thread_1, thread_2, thread_3].map(&:id)),
        )
      end
    end

    describe "step - build_load_more_url" do
      it "returns a url with the correct params" do
        expect(result.load_more_url).to eq("/chat/api/channels/#{channel_1.id}/threads?offset=10")
      end
    end
  end
end
