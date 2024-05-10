# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelsThreadsReadController do
  fab!(:current_user) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(current_user)
  end

  describe "#update" do
    context "with valid params" do
      fab!(:thread_1) { Fabricate(:chat_thread) }

      before { thread_1.add(current_user) }

      it "is a success" do
        put "/chat/api/channels/#{thread_1.channel.id}/threads/#{thread_1.id}/read.json"

        expect(response.status).to eq(200)
      end

      context "when a message_id is provided" do
        fab!(:message_1) do
          Fabricate(:chat_message, thread: thread_1, chat_channel: thread_1.channel)
        end

        it "updates the last read" do
          expect {
            put "/chat/api/channels/#{thread_1.channel.id}/threads/#{thread_1.id}/read?message_id=#{message_1.id}.json"
          }.to change { thread_1.membership_for(current_user).last_read_message_id }.from(nil).to(
            message_1.id,
          )

          expect(response.status).to eq(200)
        end
      end
    end

    context "when the thread doesn't exist" do
      fab!(:channel_1) { Fabricate(:chat_channel) }

      it "raises a not found" do
        put "/chat/api/channels/#{channel_1.id}/threads/-999/read.json"

        expect(response.status).to eq(404)
      end
    end

    context "when the user can't join associated channel" do
      fab!(:channel_1) { Fabricate(:private_category_channel) }
      fab!(:thread_1) { Fabricate(:chat_thread, channel: channel_1) }

      before { thread_1.add(current_user) }

      it "raises a not found" do
        put "/chat/api/channels/#{thread_1.channel.id}/threads/#{thread_1.id}/read.json"

        expect(response.status).to eq(403)
      end
    end
  end
end
