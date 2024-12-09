# frozen_string_literal: true

RSpec.describe DraftsController do
  fab!(:user)

  describe "#index" do
    it "requires you to be logged in" do
      get "/drafts.json"
      expect(response.status).to eq(403)
    end

    describe "when limit params is invalid" do
      before { sign_in(user) }

      include_examples "invalid limit params", "/drafts.json", described_class::INDEX_LIMIT
    end

    it "returns correct stream length after adding a draft" do
      sign_in(user)
      Draft.set(user, "xxx", 0, "{}")
      get "/drafts.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["drafts"].length).to eq(1)
    end

    it "has empty stream after deleting last draft" do
      sign_in(user)
      Draft.set(user, "xxx", 0, "{}")
      Draft.clear(user, "xxx", 0)
      get "/drafts.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["drafts"].length).to eq(0)
    end

    it "does not include topic details when user cannot see topic" do
      topic = Fabricate(:private_message_topic)
      topic_user = topic.user
      other_user = Fabricate(:user)
      Draft.set(topic_user, "topic_#{topic.id}", 0, "{}")
      Draft.set(other_user, "topic_#{topic.id}", 0, "{}")

      sign_in(topic_user)
      get "/drafts.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["drafts"].first["title"]).to eq(topic.title)

      sign_in(other_user)
      get "/drafts.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["drafts"].first["title"]).to eq(nil)
    end

    it "returns categories when lazy load categories is enabled" do
      SiteSetting.lazy_load_categories_groups = "#{Group::AUTO_GROUPS[:everyone]}"
      category = Fabricate(:category)
      topic = Fabricate(:topic, category: category)
      Draft.set(topic.user, "topic_#{topic.id}", 0, "{}")
      sign_in(topic.user)

      get "/drafts.json"
      expect(response.status).to eq(200)
      draft_keys = response.parsed_body["drafts"].map { |draft| draft["draft_key"] }
      expect(draft_keys).to contain_exactly("topic_#{topic.id}")
      category_ids = response.parsed_body["categories"].map { |cat| cat["id"] }
      expect(category_ids).to contain_exactly(category.id)
    end
  end

  describe "#show" do
    it "returns a draft if requested" do
      sign_in(user)
      Draft.set(user, "hello", 0, "test")

      get "/drafts/hello.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["draft"]).to eq("test")
    end
  end

  describe "#create" do
    it "requires you to be logged in" do
      post "/drafts.json"
      expect(response.status).to eq(403)
    end

    it "saves a draft" do
      sign_in(user)

      post "/drafts.json", params: { draft_key: "xyz", data: { my: "data" }.to_json, sequence: 0 }

      expect(response.status).to eq(200)
      expect(Draft.get(user, "xyz", 0)).to eq(%q({"my":"data"}))
    end

    it "returns 404 when the key is missing" do
      sign_in(Fabricate(:user))
      post "/drafts.json", params: { data: { my: "data" }.to_json, sequence: 0 }
      expect(response.status).to eq(404)
    end

    it "checks for a raw conflict on update" do
      sign_in(user)
      post = Fabricate(:post, user:)

      post "/drafts.json",
           params: {
             draft_key: "topic",
             sequence: 0,
             data: { postId: post.id, original_text: post.raw, action: "edit" }.to_json,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["conflict_user"]).to eq(nil)

      post "/drafts.json",
           params: {
             draft_key: "topic",
             sequence: 0,
             data: { postId: post.id, original_text: "something else", action: "edit" }.to_json,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["conflict_user"]["id"]).to eq(post.last_editor.id)
      expect(response.parsed_body["conflict_user"]).to include("avatar_template")
    end

    it "checks for a title conflict on update" do
      sign_in(user)
      post = Fabricate(:post, user:)

      post "/drafts.json",
           params: {
             draft_key: "topic",
             sequence: 0,
             data: {
               postId: post.id,
               original_text: post.raw,
               original_title: "something else",
               action: "edit",
             }.to_json,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["conflict_user"]["id"]).to eq(post.last_editor.id)
    end

    it "checks for a tag conflict on update" do
      sign_in(user)
      post = Fabricate(:post, user:)

      post "/drafts.json",
           params: {
             draft_key: "topic",
             sequence: 0,
             data: {
               postId: post.id,
               original_text: post.raw,
               original_tags: %w[tag1 tag2],
               action: "edit",
             }.to_json,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["conflict_user"]["id"]).to eq(post.last_editor.id)
    end

    it "cant trivially resolve conflicts without interaction" do
      sign_in(user)

      DraftSequence.next!(user, "abc")

      post "/drafts.json",
           params: {
             draft_key: "abc",
             sequence: 0,
             data: { a: "test" }.to_json,
             owner: "abcdefg",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["draft_sequence"]).to eq(1)
    end

    it "has a clean protocol for ownership handover" do
      sign_in(user)

      post "/drafts.json",
           params: {
             draft_key: "abc",
             sequence: 0,
             data: { a: "test" }.to_json,
             owner: "abcdefg",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["draft_sequence"]).to eq(0)

      post "/drafts.json",
           params: {
             draft_key: "abc",
             sequence: 0,
             data: { b: "test" }.to_json,
             owner: "hijklmnop",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["draft_sequence"]).to eq(1)

      expect(DraftSequence.current(user, "abc")).to eq(1)

      post "/drafts.json",
           params: {
             draft_key: "abc",
             sequence: 1,
             data: { c: "test" }.to_json,
             owner: "hijklmnop",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["draft_sequence"]).to eq(2)

      post "/drafts.json",
           params: {
             draft_key: "abc",
             sequence: 2,
             data: { c: "test" }.to_json,
             owner: "abc",
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["draft_sequence"]).to eq(3)
    end

    it "raises an error for out-of-sequence draft setting" do
      sign_in(user)
      seq = DraftSequence.next!(user, "abc")
      Draft.set(user, "abc", seq, { b: "test" }.to_json)

      post "/drafts.json",
           params: {
             draft_key: "abc",
             sequence: seq - 1,
             data: { a: "test" }.to_json,
           }

      expect(response.status).to eq(409)

      post "/drafts.json",
           params: {
             draft_key: "abc",
             sequence: seq + 1,
             data: { a: "test" }.to_json,
           }

      expect(response.status).to eq(409)
    end

    context "when data is too big" do
      let(:user) { Fabricate(:user) }
      let(:data) { "a" * (SiteSetting.max_draft_length + 1) }

      before do
        SiteSetting.max_draft_length = 500
        sign_in(user)
      end

      it "returns an error" do
        post "/drafts.json",
             params: {
               draft_key: "xyz",
               data: { reply: data }.to_json,
               sequence: 0,
             }
        expect(response).to have_http_status :bad_request
      end
    end

    context "when data is not too big" do
      context "when data is not proper JSON" do
        let(:user) { Fabricate(:user) }
        let(:data) { "not-proper-json" }

        before { sign_in(user) }

        it "returns an error" do
          post "/drafts.json", params: { draft_key: "xyz", data: data, sequence: 0 }
          expect(response).to have_http_status :bad_request
        end
      end
    end

    it "returns 403 when the maximum amount of drafts per users is reached" do
      SiteSetting.max_drafts_per_user = 2

      user1 = Fabricate(:user)
      sign_in(user1)

      data = { my: "data" }.to_json

      # creating the first draft should work
      post "/drafts.json", params: { draft_key: "TOPIC_1", data: data }
      expect(response.status).to eq(200)

      # same draft key, so shouldn't count against the limit
      post "/drafts.json", params: { draft_key: "TOPIC_1", data: data, sequence: 0 }
      expect(response.status).to eq(200)

      # different draft key, so should count against the limit
      post "/drafts.json", params: { draft_key: "TOPIC_2", data: data }
      expect(response.status).to eq(200)

      # limit should be reached now
      post "/drafts.json", params: { draft_key: "TOPIC_3", data: data }
      expect(response.status).to eq(403)

      # updating existing draft should still work
      post "/drafts.json", params: { draft_key: "TOPIC_1", data: data, sequence: 1 }
      expect(response.status).to eq(200)

      # creating a new draft as a different user should still work
      user2 = Fabricate(:user)
      sign_in(user2)
      post "/drafts.json", params: { draft_key: "TOPIC_3", data: data }
      expect(response.status).to eq(200)

      # check the draft counts just to be safe
      expect(Draft.where(user_id: user1.id).count).to eq(2)
      expect(Draft.where(user_id: user2.id).count).to eq(1)
    end
  end

  describe "#destroy" do
    it "destroys drafts when required" do
      sign_in(user)
      Draft.set(user, "xxx", 0, "hi")
      delete "/drafts/xxx.json", params: { sequence: 0 }

      expect(response.status).to eq(200)
      expect(Draft.get(user, "xxx", 0)).to eq(nil)
    end

    it "denies attempts to destroy unowned draft" do
      sign_in(Fabricate(:admin))
      user = Fabricate(:user)
      Draft.set(user, "xxx", 0, "hi")
      delete "/drafts/xxx.json", params: { sequence: 0, username: user.username }

      # Draft is not deleted because request is not via API
      expect(Draft.get(user, "xxx", 0)).to be_present
    end

    shared_examples "for a passed user" do
      it "deletes draft" do
        api_key = Fabricate(:api_key).key
        Draft.set(recipient, "xxx", 0, "hi")

        delete "/drafts/xxx.json",
               params: {
                 sequence: 0,
                 username: recipient.username,
               },
               headers: {
                 HTTP_API_USERNAME: caller.username,
                 HTTP_API_KEY: api_key,
               }

        expect(response.status).to eq(response_code)

        if draft_deleted
          expect(Draft.get(recipient, "xxx", 0)).to eq(nil)
        else
          expect(Draft.get(recipient, "xxx", 0)).to be_present
        end
      end
    end

    describe "api called by admin" do
      include_examples "for a passed user" do
        let(:caller) { Fabricate(:admin) }
        let(:recipient) { Fabricate(:user) }
        let(:response_code) { 200 }
        let(:draft_deleted) { true }
      end
    end

    describe "api called by tl4 user" do
      include_examples "for a passed user" do
        let(:caller) { Fabricate(:trust_level_4) }
        let(:recipient) { Fabricate(:user) }
        let(:response_code) { 403 }
        let(:draft_deleted) { false }
      end
    end

    describe "api called by regular user" do
      include_examples "for a passed user" do
        let(:caller) { Fabricate(:user) }
        let(:recipient) { Fabricate(:user) }
        let(:response_code) { 403 }
        let(:draft_deleted) { false }
      end
    end

    describe "api called by admin for another admin" do
      include_examples "for a passed user" do
        let(:caller) { Fabricate(:admin) }
        let(:recipient) { Fabricate(:admin) }
        let(:response_code) { 200 }
        let(:draft_deleted) { true }
      end
    end
  end
end
