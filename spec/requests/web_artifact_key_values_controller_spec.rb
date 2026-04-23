# frozen_string_literal: true

RSpec.describe WebArtifactKeyValuesController do
  fab!(:user)
  fab!(:admin)
  fab!(:topic)
  fab!(:topic_post) { Fabricate(:post, topic: topic) }
  fab!(:artifact) { Fabricate(:web_artifact, post: topic_post, metadata: { "public" => true }) }

  before { SiteSetting.web_artifact_security = "strict" }

  describe "#index" do
    fab!(:kv) { Fabricate(:web_artifact_key_value, web_artifact: artifact, user: user) }

    it "returns key values for the artifact" do
      sign_in(user)
      get "/web-artifact-key-values/#{artifact.id}.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["key_values"].length).to eq(1)
      expect(json["key_values"][0]["key"]).to eq(kv.key)
    end

    it "returns 404 for non-public artifact when user cannot see the post" do
      pm_topic = Fabricate(:private_message_topic, user: admin)
      pm_post = Fabricate(:post, topic: pm_topic, user: admin)
      private_artifact = Fabricate(:web_artifact, post: pm_post, user: admin)

      sign_in(user)
      get "/web-artifact-key-values/#{private_artifact.id}.json"
      expect(response.status).to eq(404)
    end

    it "returns 404 for orphaned non-public artifact (null post_id)" do
      orphan = Fabricate(:web_artifact, post: nil, user: admin)

      sign_in(user)
      get "/web-artifact-key-values/#{orphan.id}.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#set" do
    it "creates a new key-value pair" do
      sign_in(user)
      post "/web-artifact-key-values/#{artifact.id}.json",
           params: {
             key: "mykey",
             value: "myvalue",
           }
      expect(response.status).to eq(200)

      kv = WebArtifactKeyValue.last
      expect(kv.key).to eq("mykey")
      expect(kv.value).to eq("myvalue")
      expect(kv.user_id).to eq(user.id)
    end

    it "updates an existing key-value pair" do
      kv = Fabricate(:web_artifact_key_value, web_artifact: artifact, user: user, key: "existing")

      sign_in(user)
      post "/web-artifact-key-values/#{artifact.id}.json",
           params: {
             key: "existing",
             value: "updated",
           }
      expect(response.status).to eq(200)

      kv.reload
      expect(kv.value).to eq("updated")
    end

    it "requires login" do
      post "/web-artifact-key-values/#{artifact.id}.json", params: { key: "test", value: "val" }
      expect(response.status).to eq(403)
    end
  end

  describe "#destroy" do
    fab!(:kv) do
      Fabricate(:web_artifact_key_value, web_artifact: artifact, user: user, key: "delete_me")
    end

    it "deletes the key-value pair" do
      sign_in(user)
      delete "/web-artifact-key-values/#{artifact.id}/#{kv.key}.json"
      expect(response.status).to eq(200)
      expect(WebArtifactKeyValue.find_by(id: kv.id)).to be_nil
    end

    it "returns 404 for non-existent key" do
      sign_in(user)
      delete "/web-artifact-key-values/#{artifact.id}/nonexistent.json"
      expect(response.status).to eq(404)
    end

    it "does not allow deleting other users keys" do
      other_user = Fabricate(:user)
      sign_in(other_user)
      delete "/web-artifact-key-values/#{artifact.id}/#{kv.key}.json"
      expect(response.status).to eq(404)
    end
  end
end
