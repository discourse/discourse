# frozen_string_literal: true

RSpec.describe Chat::Api::SearchController do
  fab!(:current_user, :user)
  fab!(:channel, :chat_channel)

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    channel.add(current_user)
  end

  describe "#index" do
    context "when not logged in" do
      it "returns a 403" do
        get "/chat/api/search.json", params: { query: "test" }

        expect(response.status).to eq(403)
      end
    end

    context "when logged in" do
      before { sign_in(current_user) }

      context "when chat is disabled" do
        it "returns a 404" do
          SiteSetting.chat_enabled = false

          get "/chat/api/search.json", params: { query: "test" }

          expect(response.status).to eq(404)
        end
      end

      context "when query is missing" do
        it "returns a 400" do
          get "/chat/api/search.json", params: {}

          expect(response.status).to eq(400)
        end
      end

      context "when limit is invalid" do
        it "returns a 400 when limit is 0" do
          get "/chat/api/search.json", params: { query: "test", limit: 0 }

          expect(response.status).to eq(400)
        end

        it "returns a 400 when limit exceeds maximum" do
          get "/chat/api/search.json", params: { query: "test", limit: 41 }

          expect(response.status).to eq(400)
        end
      end

      context "when offset is negative" do
        it "returns a 400" do
          get "/chat/api/search.json", params: { query: "test", offset: -1 }

          expect(response.status).to eq(400)
        end
      end

      context "when sort is invalid" do
        it "returns a 400" do
          get "/chat/api/search.json", params: { query: "test", sort: "invalid" }

          expect(response.status).to eq(400)
        end
      end

      context "when channel_id refers to a non-existent channel" do
        it "returns a 404" do
          get "/chat/api/search.json", params: { query: "test", channel_id: -999 }

          expect(response.status).to eq(404)
        end
      end

      context "when channel_id refers to an existing channel the user cannot access" do
        fab!(:private_channel, :private_category_channel)

        it "returns a 404" do
          get "/chat/api/search.json", params: { query: "test", channel_id: private_channel.id }

          expect(response.status).to eq(404)
        end
      end

      context "when searching with valid params" do
        fab!(:message_1) do
          Fabricate(:chat_message, chat_channel: channel, message: "hello world foo bar")
        end

        before { SearchIndexer.enable }
        after { SearchIndexer.disable }

        it "returns matching messages" do
          SearchIndexer.index(message_1)

          get "/chat/api/search.json", params: { query: "hello world" }

          expect(response.status).to eq(200)
          expect(response.parsed_body["messages"].map { |m| m["id"] }).to include(message_1.id)
        end

        it "returns metadata with pagination info" do
          SearchIndexer.index(message_1)

          get "/chat/api/search.json", params: { query: "hello world", limit: 5, offset: 0 }

          expect(response.status).to eq(200)
          meta = response.parsed_body["meta"]
          expect(meta).to have_key("has_more")
          expect(meta["limit"]).to eq(5)
          expect(meta["offset"]).to eq(0)
        end

        it "scopes results to a specific channel" do
          other_channel = Fabricate(:chat_channel)
          other_channel.add(current_user)
          other_message =
            Fabricate(:chat_message, chat_channel: other_channel, message: "hello world baz")
          SearchIndexer.index(message_1)
          SearchIndexer.index(other_message)

          get "/chat/api/search.json", params: { query: "hello world", channel_id: channel.id }

          expect(response.status).to eq(200)
          ids = response.parsed_body["messages"].map { |m| m["id"] }
          expect(ids).to include(message_1.id)
          expect(ids).not_to include(other_message.id)
        end

        it "accepts sort parameter" do
          SearchIndexer.index(message_1)

          get "/chat/api/search.json", params: { query: "hello world", sort: "latest" }

          expect(response.status).to eq(200)
        end

        context "when the message is a reply in a thread whose original message was trashed" do
          fab!(:thread_channel) { Fabricate(:chat_channel, threading_enabled: true) }
          fab!(:thread_original_message) do
            Fabricate(
              :chat_message,
              chat_channel: thread_channel,
              message: "thread original message",
            )
          end
          fab!(:thread) do
            Fabricate(
              :chat_thread,
              channel: thread_channel,
              original_message: thread_original_message,
            )
          end
          fab!(:thread_reply) do
            Fabricate(
              :chat_message,
              chat_channel: thread_channel,
              thread: thread,
              message: "zebra thread reply",
            )
          end

          before do
            thread_channel.add(current_user)
            thread.update!(replies_count: 1)
            SearchIndexer.index(thread_reply, force: true)
          end

          it "does not return the reply" do
            get "/chat/api/search.json", params: { query: "zebra", channel_id: thread_channel.id }

            expect(response.status).to eq(200)
            expect(response.parsed_body["messages"].map { |m| m["id"] }).to include(thread_reply.id)

            thread_original_message.trash!

            get "/chat/api/search.json", params: { query: "zebra", channel_id: thread_channel.id }

            expect(response.status).to eq(200)
            expect(response.parsed_body["messages"].map { |m| m["id"] }).not_to include(
              thread_reply.id,
            )
          end
        end

        context "when searching without a channel_id" do
          fab!(:thread_channel) { Fabricate(:chat_channel, threading_enabled: true) }
          fab!(:thread_original_message) do
            Fabricate(
              :chat_message,
              chat_channel: thread_channel,
              message: "thread original message",
            )
          end
          fab!(:thread) do
            Fabricate(
              :chat_thread,
              channel: thread_channel,
              original_message: thread_original_message,
            )
          end
          fab!(:thread_reply) do
            Fabricate(
              :chat_message,
              chat_channel: thread_channel,
              thread: thread,
              message: "zebra threaded reply",
            )
          end
          fab!(:inline_original_message) do
            Fabricate(:chat_message, chat_channel: channel, message: "inline original message")
          end
          fab!(:inline_thread) do
            Fabricate(:chat_thread, channel: channel, original_message: inline_original_message)
          end
          fab!(:inline_reply) do
            Fabricate(
              :chat_message,
              chat_channel: channel,
              thread: inline_thread,
              message: "zebra inline reply",
            )
          end

          before do
            thread_channel.add(current_user)
            SearchIndexer.index(thread_reply, force: true)
            SearchIndexer.index(inline_reply, force: true)
          end

          it "hides replies of deleted threads but keeps replies of channels with threading disabled" do
            thread_original_message.trash!
            inline_original_message.trash!

            get "/chat/api/search.json", params: { query: "zebra" }

            expect(response.status).to eq(200)
            ids = response.parsed_body["messages"].map { |m| m["id"] }
            expect(ids).not_to include(thread_reply.id)
            expect(ids).to include(inline_reply.id)
          end

          it "returns replies of deleted threads to staff" do
            admin = Fabricate(:admin)
            thread_channel.add(admin)
            thread_original_message.trash!
            sign_in(admin)

            get "/chat/api/search.json", params: { query: "zebra" }

            expect(response.status).to eq(200)
            expect(response.parsed_body["messages"].map { |m| m["id"] }).to include(thread_reply.id)
          end
        end

        context "when a category moderator searches a channel they moderate and globally" do
          fab!(:thread_channel) do
            Fabricate(:category_channel, chatable: channel.chatable, threading_enabled: true)
          end
          fab!(:thread_original_message) do
            Fabricate(
              :chat_message,
              chat_channel: thread_channel,
              message: "thread original message",
            )
          end
          fab!(:thread) do
            Fabricate(
              :chat_thread,
              channel: thread_channel,
              original_message: thread_original_message,
            )
          end
          fab!(:thread_reply) do
            Fabricate(
              :chat_message,
              chat_channel: thread_channel,
              thread: thread,
              message: "zebra threaded reply",
            )
          end

          before do
            SiteSetting.enable_category_group_moderation = true
            category_moderators = Fabricate(:group, users: [current_user])
            Fabricate(
              :category_moderation_group,
              category: channel.chatable,
              group: category_moderators,
            )
            thread_channel.add(current_user)
            SearchIndexer.index(thread_reply, force: true)
            thread_original_message.trash!
          end

          it "returns the reply when scoped to the moderated channel" do
            get "/chat/api/search.json", params: { query: "zebra", channel_id: thread_channel.id }

            expect(response.status).to eq(200)
            expect(response.parsed_body["messages"].map { |m| m["id"] }).to include(thread_reply.id)
          end

          it "does not return the reply from a global search" do
            get "/chat/api/search.json", params: { query: "zebra" }

            expect(response.status).to eq(200)
            expect(response.parsed_body["messages"].map { |m| m["id"] }).not_to include(
              thread_reply.id,
            )
          end
        end

        context "when channel_id refers to a readonly category channel" do
          fab!(:readonly_group) { Fabricate(:group, users: [current_user]) }
          fab!(:readonly_channel) do
            category =
              Fabricate(
                :private_category,
                group: readonly_group,
                permission_type: CategoryGroup.permission_types[:readonly],
              )
            Fabricate(:category_channel, chatable: category)
          end
          fab!(:restricted_message) do
            Fabricate(
              :chat_message,
              chat_channel: readonly_channel,
              message: "Confidential restricted search message",
            )
          end

          it "does not expose scoped search results" do
            get "/chat/api/search.json",
                params: {
                  query: restricted_message.message,
                  channel_id: readonly_channel.id,
                }

            expect(response.status).to eq(404)
            expect(response.body).not_to include(restricted_message.message)
          end
        end
      end
    end
  end
end
