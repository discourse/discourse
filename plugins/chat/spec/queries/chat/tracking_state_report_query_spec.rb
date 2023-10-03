# frozen_string_literal: true

RSpec.describe Chat::TrackingStateReportQuery do
  subject(:query) do
    described_class.call(
      guardian: guardian,
      channel_ids: channel_ids,
      thread_ids: thread_ids,
      include_missing_memberships: include_missing_memberships,
      include_threads: include_threads,
      include_read: include_read,
      include_last_reply_details: include_last_reply_details,
    )
  end

  fab!(:current_user) { Fabricate(:user) }
  let(:guardian) { current_user.guardian }

  let(:channel_ids) { [] }
  let(:thread_ids) { [] }
  let(:include_missing_memberships) { false }
  let(:include_threads) { false }
  let(:include_read) { true }
  let(:include_last_reply_details) { false }
  context "when channel_ids empty" do
    it "returns empty object for channel_tracking" do
      expect(query.channel_tracking).to eq({})
    end
  end

  context "when channel_ids provided" do
    fab!(:channel_1) { Fabricate(:category_channel) }
    fab!(:channel_2) { Fabricate(:category_channel) }
    let(:channel_ids) { [channel_1.id, channel_2.id] }

    it "calls the channel unreads query with the corect params" do
      Chat::ChannelUnreadsQuery
        .expects(:call)
        .with(
          channel_ids: channel_ids,
          user_id: current_user.id,
          include_missing_memberships: include_missing_memberships,
          include_read: include_read,
        )
        .returns([])
      query
    end

    it "generates a correct unread report for the channels the user is a member of" do
      channel_1.add(current_user)
      channel_2.add(current_user)
      Fabricate(:chat_message, chat_channel: channel_1)
      Fabricate(:chat_message, chat_channel: channel_2)

      expect(query.channel_tracking).to eq(
        {
          channel_1.id => {
            unread_count: 1,
            mention_count: 0,
          },
          channel_2.id => {
            unread_count: 1,
            mention_count: 0,
          },
        },
      )
    end

    it "does not include threads by default" do
      Chat::ThreadUnreadsQuery.expects(:call).never
      expect(query.thread_tracking).to eq({})
    end

    context "when include_threads is true" do
      let(:include_threads) { true }
      fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }
      fab!(:thread_2) { Fabricate(:chat_thread, channel: channel_2) }

      before do
        channel_1.update!(threading_enabled: true)
        channel_2.update!(threading_enabled: true)
      end

      it "calls the thread unreads query with the corect params" do
        Chat::ThreadUnreadsQuery
          .expects(:call)
          .with(
            channel_ids: channel_ids,
            thread_ids: thread_ids,
            user_id: current_user.id,
            include_missing_memberships: include_missing_memberships,
            include_read: include_read,
          )
          .returns([])
        query
      end

      it "generates a correct unread for the threads the user is a member of in the channels" do
        channel_1.add(current_user)
        channel_2.add(current_user)
        thread_1.add(current_user)
        thread_2.add(current_user)
        Fabricate(:chat_message, chat_channel: channel_1, thread: thread_1)
        Fabricate(:chat_message, chat_channel: channel_2, thread: thread_2)

        expect(query.channel_tracking).to eq(
          {
            channel_1.id => {
              unread_count: 1,
              mention_count: 0,
            },
            channel_2.id => {
              unread_count: 1,
              mention_count: 0,
            },
          },
        )
        expect(query.thread_tracking).to eq(
          {
            thread_1.id => {
              unread_count: 1,
              mention_count: 0,
              channel_id: channel_1.id,
            },
            thread_2.id => {
              unread_count: 1,
              mention_count: 0,
              channel_id: channel_2.id,
            },
          },
        )
      end

      context "when include_last_reply_details is true" do
        let(:include_last_reply_details) { true }

        before do
          thread_1.add(current_user)
          thread_2.add(current_user)
          Fabricate(:chat_message, chat_channel: channel_1, thread: thread_1)
          Fabricate(:chat_message, chat_channel: channel_2, thread: thread_2)
        end

        it "gets the last_reply_created_at for each thread based on the last_message" do
          expect(query.thread_tracking).to eq(
            {
              thread_1.id => {
                unread_count: 1,
                mention_count: 0,
                channel_id: channel_1.id,
                last_reply_created_at: thread_1.reload.last_message.created_at,
              },
              thread_2.id => {
                unread_count: 1,
                mention_count: 0,
                channel_id: channel_2.id,
                last_reply_created_at: thread_2.reload.last_message.created_at,
              },
            },
          )
        end

        it "does not get the last_reply_created_at for threads where the last_message is deleted" do
          thread_1.reload.last_message.trash!
          expect(query.thread_tracking).to eq(
            {
              thread_1.id => {
                unread_count: 0,
                mention_count: 0,
                channel_id: channel_1.id,
                last_reply_created_at: nil,
              },
              thread_2.id => {
                unread_count: 1,
                mention_count: 0,
                channel_id: channel_2.id,
                last_reply_created_at: thread_2.reload.last_message.created_at,
              },
            },
          )
        end
      end

      context "when thread_ids and channel_ids is empty" do
        let(:thread_ids) { [] }
        let(:channel_ids) { [] }

        it "does not query threads" do
          Chat::ThreadUnreadsQuery.expects(:call).never
          expect(query.thread_tracking).to eq({})
        end
      end
    end
  end
end
