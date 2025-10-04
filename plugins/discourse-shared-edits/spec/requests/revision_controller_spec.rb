# frozen_string_literal: true

RSpec.describe DiscourseSharedEdits::RevisionController do
  fab!(:post1) { Fabricate(:post) }
  fab!(:admin)
  fab!(:user)

  context :admin do
    before { sign_in admin }

    it "is hard disabled when plugin is disabled" do
      SiteSetting.shared_edits_enabled = false
      put "/shared_edits/p/#{post1.id}/enable"
      expect(response.status).to eq(404)
    end

    it "is able to enable revisions on a post" do
      put "/shared_edits/p/#{post1.id}/enable"
      expect(response.status).to eq(200)

      post1.reload
      expect(post1.custom_fields[DiscourseSharedEdits::SHARED_EDITS_ENABLED]).to eq(true)

      put "/shared_edits/p/#{post1.id}/disable"
      expect(response.status).to eq(200)

      post1.reload
      expect(post1.custom_fields[DiscourseSharedEdits::SHARED_EDITS_ENABLED]).to eq(nil)
    end
  end

  context :user do
    before do
      sign_in user
      SharedEditRevision.toggle_shared_edits!(post1.id, true)
    end

    it "can submit edits on a post" do
      yjs_update = {
        content: "1234#{post1.raw[4..-1]}",
        timestamp: Time.current.to_i,
        version: 2,
      }.to_json

      put "/shared_edits/p/#{post1.id}",
          params: {
            client_id: "abc",
            version: 1,
            yjsUpdate: yjs_update,
          }
      expect(response.status).to eq(200)

      SharedEditRevision.commit!(post1.id)

      post1.reload
      expect(post1.raw[0..3]).to eq("1234")
    end

    it "can get the latest version" do
      yjs_update = {
        content: "1234#{post1.raw[4..-1]}",
        timestamp: Time.current.to_i,
        version: 2,
      }.to_json

      put "/shared_edits/p/#{post1.id}",
          params: {
            client_id: "abc",
            version: 1,
            yjsUpdate: yjs_update,
          }

      get "/shared_edits/p/#{post1.id}"
      expect(response.status).to eq(200)

      raw = response.parsed_body["raw"]
      version = response.parsed_body["version"]

      expect(raw[0..3]).to eq("1234")
      expect(version).to eq(2)
    end

    it "will defer commit" do
      Discourse.redis.del SharedEditRevision.will_commit_key(post1.id)

      Sidekiq::Testing.inline! do
        yjs_update = {
          content: "1234#{post1.raw[4..-1]}",
          timestamp: Time.current.to_i,
          version: 2,
        }.to_json

        put "/shared_edits/p/#{post1.id}",
            params: {
              client_id: "abc",
              version: 1,
              yjsUpdate: yjs_update,
            }

        get "/shared_edits/p/#{post1.id}"
        expect(response.status).to eq(200)

        raw = response.parsed_body["raw"]
        version = response.parsed_body["version"]

        expect(raw[0..3]).to eq("1234")
        expect(version).to eq(2)
      end
    end

    it "can submit old edits to a post and get sane info" do
      yjs_update1 = {
        content: "1234#{post1.raw[4..-1]}",
        timestamp: Time.current.to_i,
        version: 2,
      }.to_json

      put "/shared_edits/p/#{post1.id}",
          params: {
            client_id: "abc",
            version: 1,
            yjsUpdate: yjs_update1,
          }

      # Second client submits based on version 2 (not concurrent)
      yjs_update2 = {
        content: "1234abcd#{post1.raw[8..-1]}",
        timestamp: Time.current.to_i,
        version: 3,
      }.to_json

      put "/shared_edits/p/#{post1.id}",
          params: {
            client_id: "123",
            version: 2, # Changed from 1 to 2 - sequential edit
            yjsUpdate: yjs_update2,
          }
      expect(response.status).to eq(200)

      SharedEditRevision.commit!(post1.id)

      post1.reload
      expect(post1.raw[4..7]).to eq("abcd")
    end

    it "can not enable revisions as normal user" do
      put "/shared_edits/p/#{post1.id}/enable"
      expect(response.status).to eq(403)
      put "/shared_edits/p/#{post1.id}/disable"
      expect(response.status).to eq(403)
    end
  end
end
