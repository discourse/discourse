# frozen_string_literal: true

RSpec.describe ::Chat::TrackingState do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:channel_1) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:channel_2) { Fabricate(:chat_channel, threading_enabled: true) }
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }
    fab!(:thread_2) { Fabricate(:chat_thread, channel: channel_1) }
    fab!(:thread_3) { Fabricate(:chat_thread, channel: channel_2) }
    fab!(:thread_4) { Fabricate(:chat_thread, channel: channel_2) }

    let(:guardian) { Guardian.new(current_user) }
    let(:id_params) { { channel_ids: [channel_1.id], thread_ids: [thread_1.id] } }
    let(:include_threads) { true }
    let(:include_missing_memberships) { nil }

    let(:params) { id_params.merge(include_threads:, include_missing_memberships:) }
    let(:dependencies) { { guardian: } }

    fab!(:channel_1_membership) do
      Fabricate(:user_chat_channel_membership, chat_channel: channel_1, user: current_user)
    end
    fab!(:thread_1_membership) do
      Fabricate(:user_chat_thread_membership, thread: thread_1, user: current_user)
    end
    fab!(:thread_2_membership) do
      Fabricate(:user_chat_thread_membership, thread: thread_2, user: current_user)
    end

    context "when not including channels and threads where the user is not a member" do
      context "when only channel_ids are provided" do
        let(:id_params) { { channel_ids: [channel_1.id, channel_2.id] } }

        it "gets the tracking state of the channels" do
          generate_tracking_state
          expect(result.report.channel_tracking).to eq(
            channel_1.id => {
              unread_count: 4, # 2 messages + 2 thread original messages
              mention_count: 0,
              watched_threads_unread_count: 0,
            },
          )
        end

        it "gets the tracking state of the threads in the channels" do
          generate_tracking_state
          expect(result.report.thread_tracking).to eq(
            thread_1.id => {
              channel_id: channel_1.id,
              unread_count: 1,
              mention_count: 0,
              watched_threads_unread_count: 0,
            },
            thread_2.id => {
              channel_id: channel_1.id,
              unread_count: 2,
              mention_count: 0,
              watched_threads_unread_count: 0,
            },
          )
        end

        context "when include_threads is false" do
          let(:include_threads) { false }

          it "only gets channel tracking state and no thread tracking state" do
            generate_tracking_state
            expect(result.report.thread_tracking).to eq({})
            expect(result.report.channel_tracking).to eq(
              channel_1.id => {
                unread_count: 4, # 2 messages + 2 thread original messages
                mention_count: 0,
                watched_threads_unread_count: 0,
              },
            )
          end
        end
      end

      context "when thread_ids and channel_ids are provided" do
        let(:id_params) { { channel_ids: [channel_1.id, channel_2.id], thread_ids: [thread_2.id] } }

        it "gets the tracking state of the channels" do
          generate_tracking_state
          expect(result.report.channel_tracking).to eq(
            channel_1.id => {
              unread_count: 4, # 2 messages + 2 thread original messages
              mention_count: 0,
              watched_threads_unread_count: 0,
            },
          )
        end

        it "only gets the tracking state of the specified threads in the channels" do
          generate_tracking_state
          expect(result.report.thread_tracking).to eq(
            thread_2.id => {
              channel_id: channel_1.id,
              unread_count: 2,
              mention_count: 0,
              watched_threads_unread_count: 0,
            },
          )
        end
      end
    end

    context "when including channels and threads where the user is not a member" do
      let(:id_params) { { channel_ids: [channel_1.id, channel_2.id] } }
      let(:include_missing_memberships) { true }
      let(:include_threads) { true }

      it "gets the tracking state of all channels including the ones where the user is not a member" do
        generate_tracking_state
        expect(result.report.channel_tracking).to eq(
          channel_1.id => {
            unread_count: 4, # 2 messages + 2 thread original messages
            mention_count: 0,
            watched_threads_unread_count: 0,
          },
          channel_2.id => {
            unread_count: 0,
            mention_count: 0,
            watched_threads_unread_count: 0,
          },
        )
      end

      it "gets the tracking state of all the threads in the channels including the ones where the user is not a member" do
        generate_tracking_state
        expect(result.report.thread_tracking).to eq(
          thread_1.id => {
            channel_id: channel_1.id,
            unread_count: 1,
            mention_count: 0,
            watched_threads_unread_count: 0,
          },
          thread_2.id => {
            channel_id: channel_1.id,
            unread_count: 2,
            mention_count: 0,
            watched_threads_unread_count: 0,
          },
          thread_3.id => {
            channel_id: channel_2.id,
            unread_count: 0,
            mention_count: 0,
            watched_threads_unread_count: 0,
          },
          thread_4.id => {
            channel_id: channel_2.id,
            unread_count: 0,
            mention_count: 0,
            watched_threads_unread_count: 0,
          },
        )
      end
    end
  end

  def generate_tracking_state
    Fabricate(:chat_message, chat_channel: channel_1)
    Fabricate(:chat_message, chat_channel: channel_1)
    Fabricate(:chat_message, chat_channel: channel_1, thread: thread_1)
    Fabricate(:chat_message, chat_channel: channel_1, thread: thread_2)
    Fabricate(:chat_message, chat_channel: channel_1, thread: thread_2)
  end
end
