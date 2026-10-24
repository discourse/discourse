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

  it "serves the discarded drafts page" do
    sign_in(user)
    get "/u/#{user.username}/activity/drafts/discarded"
    expect(response.status).to eq(200)
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
      expect(response.parsed_body["draft_key"]).to eq("new_topic_1")
      expect(Draft.get(user, "new_topic_1", response.parsed_body["draft_sequence"])).to eq(content)
    end

    it "returns a conflict when a live draft has the same key" do
      draft = discarded_draft(user)
      Draft.set(user, "new_topic_1", 0, { reply: "newer" }.to_json)
      sign_in(user)

      put "/discarded_drafts/#{draft.id}/restore.json"

      expect(response.status).to eq(409)
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
