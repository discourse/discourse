# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelThreadsCurrentUserTitlePromptSeenController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel, threading_enabled: true) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }
  fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1, original_message: message_1) }
  fab!(:thread_reply) { Fabricate(:chat_message, thread: thread_1) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "#update" do
    context "when not signed in" do
      it "returns 403" do
        post "/chat/api/channels/#{channel_1.id}/threads/#{thread_1.id}/mark-thread-title-prompt-seen/me"
        expect(response.status).to eq(403)
      end
    end

    context "when signed in" do
      before do
        channel_1.add(current_user)
        sign_in(current_user)
      end

      context "when invalid" do
        it "returns 404 if channel id is not found" do
          post "/chat/api/channels/-/threads/#{thread_1.id}/mark-thread-title-prompt-seen/me"
          expect(response.status).to eq(404)
        end

        it "returns 404 if thread id is not found" do
          post "/chat/api/channels/#{channel_1.id}/threads/-/mark-thread-title-prompt-seen/me"
          expect(response.status).to eq(404)
        end

        it "returns 404 if channel threading is not enabled" do
          channel_1.update!(threading_enabled: false)
          post "/chat/api/channels/#{channel_1.id}/threads/#{thread_1.id}/mark-thread-title-prompt-seen/me"
          expect(response.status).to eq(404)
        end

        it "returns 404 if user can’t view channel" do
          channel = Fabricate(:private_category_channel)
          thread = Fabricate(:chat_thread, channel: channel)
          post "/chat/api/channels/#{channel.id}/threads/#{thread.id}/mark-thread-title-prompt-seen/me"

          expect(response.status).to eq(404)
        end
      end

      context "when valid" do
        it "updates thread_title_prompt_seen" do
          membership = thread_1.membership_for(current_user)

          expect(membership.thread_title_prompt_seen).to eq(false)

          post "/chat/api/channels/#{channel_1.id}/threads/#{thread_1.id}/mark-thread-title-prompt-seen/me"

          expect(response.status).to eq(200)

          expect(membership.reload.thread_title_prompt_seen).to eq(true)
        end

        it "creates a membership if none found" do
          random_thread = Fabricate(:chat_thread, channel: channel_1)

          expect do
            post "/chat/api/channels/#{channel_1.id}/threads/#{random_thread.id}/mark-thread-title-prompt-seen/me"
          end.to change { Chat::UserChatThreadMembership.count }.by(1)

          expect(response.status).to eq(200)
        end
      end
    end
  end
end
