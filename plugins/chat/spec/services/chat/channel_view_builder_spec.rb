# frozen_string_literal: true

RSpec.describe Chat::ChannelViewBuilder do
  describe Chat::ChannelViewBuilder::Contract, type: :model do
    it { is_expected.to validate_presence_of :channel_id }
    it do
      is_expected.to validate_inclusion_of(
        :direction,
      ).in_array Chat::MessagesQuery::VALID_DIRECTIONS
    end
  end

  describe ".call" do
    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel) { Fabricate(:category_channel) }

    let(:channel_id) { channel.id }
    let(:guardian) { current_user.guardian }
    let(:target_message_id) { nil }
    let(:page_size) { 10 }
    let(:direction) { nil }
    let(:thread_id) { nil }
    let(:fetch_from_last_read) { nil }
    let(:params) do
      {
        guardian: guardian,
        channel_id: channel_id,
        target_message_id: target_message_id,
        fetch_from_last_read: fetch_from_last_read,
        page_size: page_size,
        direction: direction,
        thread_id: thread_id,
      }
    end

    subject(:result) { described_class.call(params) }

    it "threads_enabled is false by default" do
      expect(subject.threads_enabled).to eq(false)
    end

    it "include_thread_messages is true by default" do
      expect(subject.include_thread_messages).to eq(true)
    end

    it "queries messages" do
      Chat::MessagesQuery
        .expects(:call)
        .with(
          channel: channel,
          guardian: guardian,
          target_message_id: target_message_id,
          thread_id: thread_id,
          include_thread_messages: true,
          page_size: page_size,
          direction: direction,
        )
        .returns({ messages: [] })
      subject
    end

    it "returns channel messages and thread replies" do
      message_1 = Fabricate(:chat_message, chat_channel: channel)
      message_2 = Fabricate(:chat_message, chat_channel: channel)
      message_3 =
        Fabricate(
          :chat_message,
          chat_channel: channel,
          thread: Fabricate(:chat_thread, channel: channel),
        )
      expect(subject.view.chat_messages).to eq(
        [message_1, message_2, message_3.thread.original_message, message_3],
      )
    end

    it "does not query thread tracking overview or state by default" do
      Chat::TrackingStateReportQuery.expects(:call).never
      subject
    end

    it "does not query threads by default" do
      Chat::Thread.expects(:where).never
      subject
    end

    it "returns a Chat::View" do
      expect(subject.view).to be_a(Chat::View)
    end

    context "when page_size is null" do
      let(:page_size) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when page_size is too big" do
      let(:page_size) { Chat::MessagesQuery::MAX_PAGE_SIZE + 1 }

      it { is_expected.to fail_a_contract }
    end

    context "when channel has threading_enabled and enable_experimental_chat_threaded_discussions is true" do
      before do
        channel.update!(threading_enabled: true)
        SiteSetting.enable_experimental_chat_threaded_discussions = true
      end

      it "threads_enabled is true" do
        expect(subject.threads_enabled).to eq(true)
      end

      it "include_thread_messages is false" do
        expect(subject.include_thread_messages).to eq(false)
      end

      it "returns channel messages but not thread replies" do
        message_1 = Fabricate(:chat_message, chat_channel: channel)
        message_2 = Fabricate(:chat_message, chat_channel: channel)
        message_3 =
          Fabricate(
            :chat_message,
            chat_channel: channel,
            thread: Fabricate(:chat_thread, channel: channel),
          )
        expect(subject.view.chat_messages).to eq(
          [message_1, message_2, message_3.thread.original_message],
        )
      end

      it "fetches threads for any messages that have a thread id" do
        message_1 =
          Fabricate(
            :chat_message,
            chat_channel: channel,
            thread: Fabricate(:chat_thread, channel: channel),
          )
        expect(subject.view.threads).to eq([message_1.thread])
      end

      it "fetches thread memberships for the current user for fetched threads" do
        message_1 =
          Fabricate(
            :chat_message,
            chat_channel: channel,
            thread: Fabricate(:chat_thread, channel: channel),
          )
        message_1.thread.add(current_user)
        expect(subject.view.thread_memberships).to eq(
          [message_1.thread.membership_for(current_user)],
        )
      end

      it "calls the tracking state report query for thread overview and tracking" do
        thread = Fabricate(:chat_thread, channel: channel)
        message_1 = Fabricate(:chat_message, chat_channel: channel, thread: thread)
        ::Chat::TrackingStateReportQuery
          .expects(:call)
          .with(
            guardian: guardian,
            channel_ids: [channel.id],
            include_threads: true,
            include_read: false,
          )
          .returns(Chat::TrackingStateReport.new)
          .once
        ::Chat::TrackingStateReportQuery
          .expects(:call)
          .with(guardian: guardian, thread_ids: [thread.id], include_threads: true)
          .returns(Chat::TrackingStateReport.new)
          .once
        subject
      end

      it "fetches an overview of threads with unread messages in the channel" do
        thread = Fabricate(:chat_thread, channel: channel)
        thread.add(current_user)
        message_1 = Fabricate(:chat_message, chat_channel: channel, thread: thread)
        expect(subject.view.unread_thread_ids).to eq([message_1.thread.id])
      end

      it "fetches the tracking state of threads in the channel" do
        thread = Fabricate(:chat_thread, channel: channel)
        thread.add(current_user)
        Fabricate(:chat_message, chat_channel: channel, thread: thread)
        expect(subject.view.tracking.thread_tracking).to eq(
          { thread.id => { channel_id: channel.id, unread_count: 1, mention_count: 0 } },
        )
      end

      context "when a thread_id is provided" do
        let(:thread_id) { Fabricate(:chat_thread, channel: channel).id }

        it "include_thread_messages is true" do
          expect(subject.include_thread_messages).to eq(true)
        end
      end
    end

    context "when channel is not found" do
      before { channel.destroy! }

      it { is_expected.to fail_to_find_a_model(:channel) }
    end

    context "when user cannot access the channel" do
      fab!(:channel) { Fabricate(:private_category_channel) }

      it { is_expected.to fail_a_policy(:can_view_channel) }
    end

    context "when fetch_from_last_read is true" do
      let(:fetch_from_last_read) { true }
      fab!(:message) { Fabricate(:chat_message, chat_channel: channel) }
      fab!(:past_message_1) do
        msg = Fabricate(:chat_message, chat_channel: channel)
        msg.update!(created_at: message.created_at - 1.day)
        msg
      end
      fab!(:past_message_2) do
        msg = Fabricate(:chat_message, chat_channel: channel)
        msg.update!(created_at: message.created_at - 2.days)
        msg
      end

      context "when page_size is null" do
        let(:page_size) { nil }

        it { is_expected.not_to fail_a_contract }
      end

      context "if the user is not a member of the channel" do
        it "does not error and still returns messages" do
          expect(subject.view.chat_messages).to eq([past_message_2, past_message_1, message])
        end
      end

      context "if the user is a member of the channel" do
        fab!(:membership) do
          Fabricate(:user_chat_channel_membership, user: current_user, chat_channel: channel)
        end

        context "if the user's last_read_message_id is not nil" do
          before { membership.update!(last_read_message_id: past_message_1.id) }

          it "uses the last_read_message_id of the user's membership as the target_message_id" do
            expect(subject.view.chat_messages).to eq([past_message_2, past_message_1, message])
          end
        end

        context "if the user's last_read_message_id is nil" do
          before { membership.update!(last_read_message_id: nil) }

          it "does not error and still returns messages" do
            expect(subject.view.chat_messages).to eq([past_message_2, past_message_1, message])
          end

          context "if page_size is nil" do
            let(:page_size) { nil }

            it "calls the messages query with the default page size" do
              ::Chat::MessagesQuery
                .expects(:call)
                .with(has_entries(page_size: Chat::MessagesQuery::MAX_PAGE_SIZE))
                .once
                .returns({ messages: [] })
              subject
            end
          end
        end
      end
    end

    context "when target_message_id provided" do
      fab!(:message) { Fabricate(:chat_message, chat_channel: channel) }
      fab!(:past_message) do
        msg = Fabricate(:chat_message, chat_channel: channel)
        msg.update!(created_at: message.created_at - 1.day)
        msg
      end
      fab!(:future_message) do
        msg = Fabricate(:chat_message, chat_channel: channel)
        msg.update!(created_at: message.created_at + 1.day)
        msg
      end
      let(:target_message_id) { message.id }

      it "includes the target message as well as past and future messages" do
        expect(subject.view.chat_messages).to eq([past_message, message, future_message])
      end

      context "when page_size is null" do
        let(:page_size) { nil }

        it { is_expected.not_to fail_a_contract }
      end

      context "when the target message is a thread reply" do
        fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

        before { message.update!(thread: thread) }

        it "includes it by default" do
          expect(subject.view.chat_messages).to eq(
            [past_message, message, thread.original_message, future_message],
          )
        end

        context "when not including thread messages" do
          before do
            channel.update!(threading_enabled: true)
            SiteSetting.enable_experimental_chat_threaded_discussions = true
          end

          it "does not include the target message" do
            expect(subject.view.chat_messages).to eq(
              [past_message, thread.original_message, future_message],
            )
          end
        end
      end

      context "when the message does not exist" do
        before { message.trash! }

        it { is_expected.to fail_a_policy(:target_message_exists) }

        context "when the user is the owner of the trashed message" do
          before { message.update!(user: current_user) }

          it { is_expected.not_to fail_a_policy(:target_message_exists) }
        end

        context "when the user is admin" do
          before { current_user.update!(admin: true) }

          it { is_expected.not_to fail_a_policy(:target_message_exists) }
        end
      end
    end
  end
end
