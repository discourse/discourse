# frozen_string_literal: true

RSpec.describe DiscardedDraftsController do
  fab!(:user)
  fab!(:other_user, :user)

  let(:content) { { reply: "worth keeping" }.to_json }

  def discarded_draft(owner, key = "new_topic_1")
    Draft.set(owner, key, 0, content)
    Draft.clear(owner, key, 0)
    Draft.discarded.find_by(user: owner, draft_key: key)
  end

  it "requires login" do
    get "/discarded_drafts.json"
    expect(response.status).to eq(403)
  end

  describe "#index" do
    it "lists only the current user's discarded drafts" do
      own = discarded_draft(user)
      discarded_draft(other_user)
      Draft.set(user, "new_topic_2", 0, content)
      sign_in(user)

      get "/discarded_drafts.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["discarded_drafts"].map { |d| d["id"] }).to contain_exactly(
        own.id,
      )
    end
  end

  describe "#restore" do
    it "restores the draft" do
      draft = discarded_draft(user)
      sign_in(user)

      put "/discarded_drafts/#{draft.id}/restore.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["draft"]).to eq(content)
      restored_sequence = response.parsed_body["draft_sequence"]
      expect(restored_sequence).to eq(1)
      expect(Draft.get(user, "new_topic_1", restored_sequence)).to eq(content)

      post "/drafts.json",
           params: {
             draft_key: "new_topic_1",
             sequence: 0,
             data: { reply: "stale" }.to_json,
           }

      expect(response.status).to eq(409)
      expect(Draft.get(user, "new_topic_1", restored_sequence)).to eq(content)

      edited_content = { reply: "edited after restoring" }.to_json
      post "/drafts.json",
           params: {
             draft_key: "new_topic_1",
             sequence: restored_sequence,
             data: edited_content,
           }

      expect(response.status).to eq(200)
      expect(Draft.get(user, "new_topic_1", response.parsed_body["draft_sequence"])).to eq(
        edited_content,
      )
    end

    it "returns a conflict when a live draft has the same key" do
      draft = discarded_draft(user)
      Draft.set(user, "new_topic_1", 0, { reply: "newer" }.to_json)
      sign_in(user)

      put "/discarded_drafts/#{draft.id}/restore.json"

      expect(response.status).to eq(409)
      expect(draft.reload.deleted_at).to be_present
      expect(DraftSequence.current(user, "new_topic_1")).to eq(0)
      expect(Draft.get(user, "new_topic_1", 0)).to eq({ reply: "newer" }.to_json)
    end

    it "enforces the draft limit" do
      SiteSetting.max_drafts_per_user = 1
      draft = discarded_draft(user)
      Draft.set(user, "new_topic_2", 0, content)
      sign_in(user)

      put "/discarded_drafts/#{draft.id}/restore.json"

      expect(response.status).to eq(403)
      expect(draft.reload.deleted_at).to be_present
    end

    it "does not restore another user's draft" do
      draft = discarded_draft(other_user)
      sign_in(user)

      put "/discarded_drafts/#{draft.id}/restore.json"

      expect(response.status).to eq(404)
      expect(draft.reload.deleted_at).to be_present
    end
  end

  describe "#destroy" do
    it "keeps a draft restored after the deletion request loads it" do
      upload = Fabricate(:upload)
      key = "new_topic_1"
      Draft.set(user, key, 0, { reply: "![image](#{upload.short_url})" }.to_json)
      Draft.clear(user, key, 0)
      draft = Draft.discarded.find_by!(user: user, draft_key: key)
      sign_in(user)

      allow_any_instance_of(DiscardedDraftsController).to receive(
        :find_discarded_draft,
      ).and_wrap_original do |original, *args|
        loaded = original.call(*args)
        Draft.find(loaded.id).restore!
        loaded
      end

      delete "/discarded_drafts/#{draft.id}.json"

      expect(response.status).to eq(404)
      expect(Draft.live.where(id: draft.id)).to exist
      expect(UploadReference.where(target_type: "Draft", target_id: draft.id)).to exist
    end

    it "deletes the draft permanently" do
      draft = discarded_draft(user)
      sign_in(user)

      delete "/discarded_drafts/#{draft.id}.json"

      expect(response.status).to eq(204)
      expect(Draft.exists?(draft.id)).to eq(false)
    end

    it "does not delete live drafts or another user's drafts" do
      Draft.set(user, "new_topic_2", 0, content)
      live_id = Draft.live.find_by(user: user).id
      other = discarded_draft(other_user)
      sign_in(user)

      delete "/discarded_drafts/#{live_id}.json"
      expect(response.status).to eq(404)

      delete "/discarded_drafts/#{other.id}.json"
      expect(response.status).to eq(404)

      expect(Draft.where(id: [live_id, other.id]).count).to eq(2)
    end
  end
end
