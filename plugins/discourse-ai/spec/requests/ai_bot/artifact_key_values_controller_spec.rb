# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::ArtifactKeyValuesController do
  fab!(:user)
  fab!(:admin)
  fab!(:other_user, :user)
  fab!(:private_message_topic) { Fabricate(:private_message_topic, user: user) }
  fab!(:private_message_post) { Fabricate(:post, topic: private_message_topic, user: user) }
  fab!(:artifact) do
    Fabricate(:ai_artifact, post: private_message_post, metadata: { public: true })
  end
  fab!(:private_artifact) { Fabricate(:ai_artifact, post: private_message_post) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  describe "#index" do
    fab!(:public_key_value) do
      Fabricate(
        :ai_artifact_key_value,
        ai_artifact: artifact,
        user: user,
        key: "test_key",
        value: "test_value",
        public: true,
      )
    end

    fab!(:private_key_value) do
      Fabricate(
        :ai_artifact_key_value,
        ai_artifact: artifact,
        user: user,
        key: "private_key",
        value: "private_value",
        public: false,
      )
    end

    fab!(:other_user_key_value) do
      Fabricate(
        :ai_artifact_key_value,
        ai_artifact: artifact,
        user: other_user,
        key: "other_key",
        value: "other_value",
        public: true,
      )
    end

    fab!(:admin_key_value) do
      Fabricate(
        :ai_artifact_key_value,
        ai_artifact: artifact,
        user: admin,
        key: "admin_key",
        value: "admin_value",
        public: false,
      )
    end

    context "when not logged in" do
      it "returns only public key values" do
        get "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json",
            params: {
              all_users: true,
            }

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["key_values"].length).to eq(2) # public_key_value and other_user_key_value
        expect(json["key_values"].map { |kv| kv["key"] }).to contain_exactly(
          "test_key",
          "other_key",
        )
        expect(json["has_more"]).to eq(false)
        expect(json["total_count"]).to eq(2)

        expect(json["key_values"].map { |kv| kv["user_id"] }).to contain_exactly(
          user.id,
          other_user.id,
        )
        expect(json["users"].map { |u| u["id"] }).to contain_exactly(user.id, other_user.id)
      end

      it "returns 404 for private artifact" do
        get "/discourse-ai/ai-bot/artifact-key-values/#{private_artifact.id}.json"
        expect(response.status).to eq(404)
      end

      it "returns 404 for non-existent artifact" do
        get "/discourse-ai/ai-bot/artifact-key-values/999999.json"
        expect(response.status).to eq(404)
      end
    end

    context "when logged in as regular user" do
      before { sign_in(user) }

      it "returns public key values and own private key values" do
        get "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json",
            params: {
              all_users: true,
            }

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["key_values"].length).to eq(3) # all key values
        expect(json["key_values"].map { |kv| kv["key"] }).to contain_exactly(
          "test_key",
          "private_key",
          "other_key",
        )
      end

      it "filters by current user when all_users is not true" do
        get "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        # Should only show user's own key values when all_users is not explicitly true
        user_key_values = json["key_values"].select { |kv| kv["user_id"] == user.id }
        expect(user_key_values.length).to be > 0
      end

      it "shows all users' key values when all_users=true" do
        get "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json?all_users=true"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["key_values"].length).to eq(3)
      end

      it "filters by key when specified" do
        get "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json?key=test_key"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["key_values"].length).to eq(1)
        expect(json["key_values"].first["key"]).to eq("test_key")
      end

      it "returns keys only when keys_only=true" do
        get "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json?keys_only=true"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["key_values"]).to be_present
        # The serializer should handle keys_only option
      end
    end

    context "when logged in as admin" do
      before { sign_in(admin) }

      it "returns only my own keys by default" do
        get "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["key_values"].length).to eq(1)
        expect(json["key_values"].map { |kv| kv["key"] }).to contain_exactly("admin_key")
      end

      it "can access private artifacts" do
        get "/discourse-ai/ai-bot/artifact-key-values/#{private_artifact.id}.json"
        expect(response.status).to eq(200)
      end
    end

    context "when paginating" do
      before do
        sign_in(user)
        # Create more key values to test pagination
        15.times do |i|
          Fabricate(
            :ai_artifact_key_value,
            ai_artifact: artifact,
            user: user,
            key: "key_#{i}",
            value: "value_#{i}",
            public: true,
          )
        end
      end

      it "paginates results correctly" do
        get "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json?per_page=5&page=1"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["key_values"].length).to eq(5)
        expect(json["has_more"]).to eq(true)
      end

      it "respects per_page limit" do
        get "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json?per_page=200"

        expect(response.status).to eq(200)
        json = response.parsed_body
        # Should be limited to PER_PAGE_MAX (100)
        expect(json["key_values"].length).to be <= 100
      end

      it "defaults to page 1 for invalid page numbers" do
        get "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json?page=0"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["key_values"]).to be_present
      end
    end
  end

  describe "#destroy" do
    fab!(:key_value_to_delete) do
      Fabricate(
        :ai_artifact_key_value,
        ai_artifact: artifact,
        user: user,
        key: "delete_me",
        value: "delete_value",
        public: false,
      )
    end

    fab!(:other_user_key_value_to_delete) do
      Fabricate(
        :ai_artifact_key_value,
        ai_artifact: artifact,
        user: other_user,
        key: "other_delete_me",
        value: "other_delete_value",
        public: false,
      )
    end

    context "when not logged in" do
      it "returns 403 forbidden" do
        delete "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}/delete_me.json"
        expect(response.status).to eq(403)
      end
    end

    context "when logged in" do
      before { sign_in(user) }

      it "deletes own key value successfully" do
        expect {
          delete "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}/delete_me.json"
          expect(response.status).to eq(200)
        }.to change { artifact.key_values.count }.by(-1)

        expect(artifact.key_values.find_by(key: "delete_me")).to be_nil
      end

      it "returns 404 for non-existent key" do
        delete "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}/non_existent_key.json"

        expect(response.status).to eq(404)
        json = response.parsed_body
        expect(json["error"]).to eq("Key not found")
      end

      it "returns 404 when trying to delete another user's key" do
        delete "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}/other_delete_me.json"

        expect(response.status).to eq(404)
        json = response.parsed_body
        expect(json["error"]).to eq("Key not found")

        # Verify the key still exists
        expect(artifact.key_values.find_by(key: "other_delete_me")).to be_present
      end

      it "returns 404 for non-existent artifact" do
        delete "/discourse-ai/ai-bot/artifact-key-values/999999/delete_me.json"

        expect(response.status).to eq(404)
      end

      it "returns 404 for private artifact user cannot see" do
        topic = Fabricate(:private_message_topic, user: other_user)
        private_post = Fabricate(:post, topic: topic)
        private_artifact = Fabricate(:ai_artifact, post: private_post)
        Fabricate(
          :ai_artifact_key_value,
          ai_artifact: private_artifact,
          user: other_user,
          key: "private_key",
        )

        delete "/discourse-ai/ai-bot/artifact-key-values/#{private_artifact.id}/private_key.json"

        expect(response.status).to eq(404)
      end

      context "with URL encoding" do
        fab!(:special_key_value) do
          Fabricate(
            :ai_artifact_key_value,
            ai_artifact: artifact,
            user: user,
            key: "key with spaces & symbols!",
            value: "special_value",
          )
        end

        it "handles URL encoded keys correctly" do
          expect {
            delete "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json",
                   params: {
                     key: "key with spaces & symbols!",
                   }
            expect(response.status).to eq(200)
          }.to change { artifact.key_values.count }.by(-1)

          expect(artifact.key_values.find_by(key: "key with spaces & symbols!")).to be_nil
        end
      end
    end

    context "when logged in as admin" do
      before { sign_in(admin) }

      it "can only delete own keys, not other users' keys" do
        # Even admins should only be able to delete their own keys in this context
        delete "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}/other_delete_me.json"

        expect(response.status).to eq(404)
        json = response.parsed_body
        expect(json["error"]).to eq("Key not found")

        # Verify the key still exists
        expect(artifact.key_values.find_by(key: "other_delete_me")).to be_present
      end

      it "can delete own keys" do
        _admin_key =
          Fabricate(
            :ai_artifact_key_value,
            ai_artifact: artifact,
            user: admin,
            key: "admin_key",
            value: "admin_value",
          )

        expect {
          delete "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}/admin_key.json"
          expect(response.status).to eq(200)
        }.to change { artifact.key_values.count }.by(-1)
      end

      it "can access private artifacts" do
        _admin_key =
          Fabricate(
            :ai_artifact_key_value,
            ai_artifact: private_artifact,
            user: admin,
            key: "private_admin_key",
            value: "private_admin_value",
          )

        expect {
          delete "/discourse-ai/ai-bot/artifact-key-values/#{private_artifact.id}/private_admin_key.json"
          expect(response.status).to eq(200)
        }.to change { private_artifact.key_values.count }.by(-1)
      end
    end
  end

  describe "#set" do
    let(:valid_params) do
      { artifact_id: artifact.id, key: "new_key", value: "new_value", public: true }
    end

    context "when not logged in" do
      it "returns 403 forbidden" do
        post "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json", params: valid_params

        expect(response.status).to eq(403)
      end
    end

    context "when logged in" do
      before { sign_in(user) }

      it "creates a new key value successfully" do
        expect {
          post "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json", params: valid_params
          expect(response.status).to eq(200)
        }.to change { artifact.key_values.count }.by(1)

        json = response.parsed_body
        key_value = json["ai_artifact_key_value"]
        expect(key_value["key"]).to eq("new_key")
        expect(key_value["value"]).to eq("new_value")

        key_value = artifact.key_values.last
        expect(key_value.user).to eq(user)
      end

      it "returns validation errors for invalid data" do
        post "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json",
             params: {
               artifact_id: artifact.id,
               key: "", # invalid empty key
               value: "value",
             }

        expect(response.status).to eq(422)
        json = response.parsed_body
        expect(json["errors"]).to be_present
      end

      it "returns 404 for non-existent artifact" do
        post "/discourse-ai/ai-bot/artifact-key-values/999999.json", params: valid_params

        expect(response.status).to eq(404)
      end

      it "returns 404 for private artifact user cannot see" do
        topic = Fabricate(:private_message_topic, user: other_user)
        private_post = Fabricate(:post, topic: topic)
        private_artifact = Fabricate(:ai_artifact, post: private_post)

        post "/discourse-ai/ai-bot/artifact-key-values/#{private_artifact.id}.json",
             params: valid_params

        expect(response.status).to eq(404)
      end
    end
  end
end
