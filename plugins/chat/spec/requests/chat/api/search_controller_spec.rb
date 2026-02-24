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
      end
    end
  end
end
