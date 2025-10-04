# frozen_string_literal: true

describe "Concurrent Revisions", type: :request do
  fab!(:admin)
  fab!(:user1) { Fabricate(:user, username: "user1") }
  fab!(:user2) { Fabricate(:user, username: "user2") }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, user: admin, raw: "Original content") }

  before do
    SiteSetting.shared_edits_enabled = true
    SharedEditRevision.toggle_shared_edits!(post.id, true)
  end

  describe "concurrent PUT requests from multiple users" do
    it "handles simultaneous updates without losing data" do
      # Get initial version
      sign_in(user1)
      get "/shared_edits/p/#{post.id}.json"
      expect(response.status).to eq(200)
      initial_version = JSON.parse(response.body)["version"]

      # Simulate two users editing simultaneously
      user1_update = [1, 2, 3, 4, 5]
      user2_update = [6, 7, 8, 9, 10]

      # User 1 sends update
      sign_in(user1)
      put "/shared_edits/p/#{post.id}.json",
          params: {
            yjsUpdate: user1_update,
            version: initial_version,
            raw: "User 1 content",
            client_id: "client1",
          }

      expect(response.status).to eq(200)
      user1_version = JSON.parse(response.body)["version"]
      expect(user1_version).to be > initial_version

      # User 2 sends update (overlapping with user 1)
      sign_in(user2)
      put "/shared_edits/p/#{post.id}.json",
          params: {
            yjsUpdate: user2_update,
            version: initial_version,
            raw: "User 2 content",
            client_id: "client2",
          }

      expect(response.status).to eq(200)
      user2_version = JSON.parse(response.body)["version"]
      expect(user2_version).to be > user1_version

      # Both revisions should be saved
      revisions = SharedEditRevision.where(post_id: post.id).order(:version)
      expect(revisions.count).to be >= 3 # initial + user1 + user2

      # Check that both users' changes are recorded
      user1_revisions = revisions.where(user_id: user1.id)
      user2_revisions = revisions.where(user_id: user2.id)

      expect(user1_revisions.exists?).to eq(true)
      expect(user2_revisions.exists?).to eq(true)
    end

    it "handles rapid successive updates from same user" do
      sign_in(user1)
      get "/shared_edits/p/#{post.id}.json"
      version = JSON.parse(response.body)["version"]

      # Send 5 rapid updates
      5.times do |i|
        put "/shared_edits/p/#{post.id}.json",
            params: {
              yjsUpdate: [i, i + 1, i + 2],
              version: version,
              raw: "Content #{i}",
              client_id: "client1",
            }

        expect(response.status).to eq(200)
        version = JSON.parse(response.body)["version"]
      end

      # All updates should be saved
      revisions = SharedEditRevision.where(post_id: post.id, user_id: user1.id)
      expect(revisions.count).to be >= 5
    end

    it "handles interleaved updates from three users" do
      user3 = Fabricate(:user, username: "user3")

      sign_in(user1)
      get "/shared_edits/p/#{post.id}.json"
      base_version = JSON.parse(response.body)["version"]

      updates = []

      # User 1 updates
      sign_in(user1)
      put "/shared_edits/p/#{post.id}.json",
          params: {
            yjsUpdate: [1, 1, 1],
            version: base_version,
            raw: "User 1 v1",
            client_id: "client1",
          }
      updates << JSON.parse(response.body)["version"]

      # User 2 updates (based on base_version)
      sign_in(user2)
      put "/shared_edits/p/#{post.id}.json",
          params: {
            yjsUpdate: [2, 2, 2],
            version: base_version,
            raw: "User 2 v1",
            client_id: "client2",
          }
      updates << JSON.parse(response.body)["version"]

      # User 3 updates (based on user 1's version)
      sign_in(user3)
      put "/shared_edits/p/#{post.id}.json",
          params: {
            yjsUpdate: [3, 3, 3],
            version: updates[0],
            raw: "User 3 v1",
            client_id: "client3",
          }
      updates << JSON.parse(response.body)["version"]

      # User 1 updates again (based on user 2's version)
      sign_in(user1)
      put "/shared_edits/p/#{post.id}.json",
          params: {
            yjsUpdate: [1, 1, 1, 1],
            version: updates[1],
            raw: "User 1 v2",
            client_id: "client1",
          }
      updates << JSON.parse(response.body)["version"]

      # All versions should be strictly increasing
      expect(updates).to eq(updates.sort)

      # All users should have revisions
      expect(SharedEditRevision.where(post_id: post.id, user_id: user1.id).exists?).to eq(true)
      expect(SharedEditRevision.where(post_id: post.id, user_id: user2.id).exists?).to eq(true)
      expect(SharedEditRevision.where(post_id: post.id, user_id: user3.id).exists?).to eq(true)
    end

    it "handles version conflicts gracefully" do
      sign_in(user1)
      get "/shared_edits/p/#{post.id}.json"
      version = JSON.parse(response.body)["version"]

      # User 1 updates successfully
      put "/shared_edits/p/#{post.id}.json",
          params: {
            yjsUpdate: [1, 2, 3],
            version: version,
            raw: "User 1 content",
            client_id: "client1",
          }

      expect(response.status).to eq(200)
      new_version = JSON.parse(response.body)["version"]

      # User 2 tries to update with old version
      sign_in(user2)
      put "/shared_edits/p/#{post.id}.json",
          params: {
            yjsUpdate: [4, 5, 6],
            version: version, # Old version!
            raw: "User 2 content",
            client_id: "client2",
          }

      # Should still succeed (YJS handles conflicts)
      expect(response.status).to eq(200)
      user2_version = JSON.parse(response.body)["version"]
      expect(user2_version).to be > new_version
    end

    it "preserves all intermediate states" do
      sign_in(user1)
      get "/shared_edits/p/#{post.id}.json"
      version = JSON.parse(response.body)["version"]

      contents = %w[First Second Third Fourth Fifth]
      versions = []

      contents.each do |content|
        put "/shared_edits/p/#{post.id}.json",
            params: {
              yjsUpdate: [1, 2, 3],
              version: version,
              raw: content,
              client_id: "client1",
            }

        version = JSON.parse(response.body)["version"]
        versions << version
      end

      # Check all intermediate states exist
      contents.each_with_index do |content, i|
        revision = SharedEditRevision.find_by(post_id: post.id, version: versions[i])
        expect(revision).to be_present
        expect(revision.raw).to eq(content)
      end
    end
  end

  describe "awareness updates with document updates" do
    it "handles awareness-only updates without document changes" do
      sign_in(user1)
      get "/shared_edits/p/#{post.id}.json"
      version = JSON.parse(response.body)["version"]

      # Send awareness update only
      put "/shared_edits/p/#{post.id}.json",
          params: {
            awareness: [1, 2, 3, 4, 5],
            version: version,
            client_id: "client1",
          }

      expect(response.status).to eq(200)

      # Version should not change for awareness-only updates
      new_version = JSON.parse(response.body)["version"]
      expect(new_version).to eq(version)
    end

    it "handles combined awareness and document updates" do
      sign_in(user1)
      get "/shared_edits/p/#{post.id}.json"
      version = JSON.parse(response.body)["version"]

      # Send both awareness and document update
      put "/shared_edits/p/#{post.id}.json",
          params: {
            yjsUpdate: [1, 2, 3],
            awareness: [4, 5, 6],
            version: version,
            raw: "Updated content",
            client_id: "client1",
          }

      expect(response.status).to eq(200)

      # Version should increment for document updates
      new_version = JSON.parse(response.body)["version"]
      expect(new_version).to be > version
    end
  end

  describe "concurrent commit operations" do
    it "handles multiple users committing simultaneously" do
      # User 1 and User 2 both make edits
      sign_in(user1)
      get "/shared_edits/p/#{post.id}.json"
      version1 = JSON.parse(response.body)["version"]

      put "/shared_edits/p/#{post.id}.json",
          params: {
            yjsUpdate: [1, 2, 3],
            version: version1,
            raw: "User 1 final",
            client_id: "client1",
          }

      sign_in(user2)
      put "/shared_edits/p/#{post.id}.json",
          params: {
            yjsUpdate: [4, 5, 6],
            version: version1,
            raw: "User 2 final",
            client_id: "client2",
          }

      # Both try to commit
      sign_in(user1)
      put "/shared_edits/p/#{post.id}/commit.json",
          params: {
            yjsState: [1, 2, 3, 4, 5, 6],
            client_id: "client1",
          }

      expect(response.status).to eq(200)

      sign_in(user2)
      put "/shared_edits/p/#{post.id}/commit.json",
          params: {
            yjsState: [1, 2, 3, 4, 5, 6, 7],
            client_id: "client2",
          }

      expect(response.status).to eq(200)
    end
  end

  describe "error recovery" do
    it "recovers from invalid YJS data" do
      sign_in(user1)
      get "/shared_edits/p/#{post.id}.json"
      version = JSON.parse(response.body)["version"]

      # Send invalid data
      put "/shared_edits/p/#{post.id}.json",
          params: {
            yjsUpdate: "invalid",
            version: version,
            raw: "Content",
            client_id: "client1",
          }

      # Should handle gracefully
      expect(response.status).to satisfy { |status| [200, 422].include?(status) }
    end

    it "handles missing required parameters" do
      sign_in(user1)

      # Missing yjsUpdate and awareness
      put "/shared_edits/p/#{post.id}.json", params: { version: 1 }

      # Should not crash
      expect(response.status).to satisfy { |status| [200, 400, 422].include?(status) }
    end
  end

  describe "message bus integration" do
    it "broadcasts updates to other clients" do
      messages = []
      MessageBus.subscribe("/shared_edits/#{post.id}") { |msg| messages << msg }

      sign_in(user1)
      get "/shared_edits/p/#{post.id}.json"
      version = JSON.parse(response.body)["version"]

      put "/shared_edits/p/#{post.id}.json",
          params: {
            yjsUpdate: [1, 2, 3],
            version: version,
            raw: "Updated",
            client_id: "client1",
          }

      # Give message bus time to process
      wait_for { messages.length > 0 }

      expect(messages.length).to be > 0
      expect(messages.last.data["client_id"]).to eq("client1")
    ensure
      MessageBus.unsubscribe("/shared_edits/#{post.id}")
    end
  end
end
