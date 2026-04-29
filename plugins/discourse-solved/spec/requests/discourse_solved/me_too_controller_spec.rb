# frozen_string_literal: true

RSpec.describe DiscourseSolved::MeTooController do
  fab!(:author, :user)
  fab!(:acting_user, :user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category:, user: author) }
  fab!(:post_1, :post) { Fabricate(:post, topic:) }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = true
    SiteSetting.enable_solved_me_too = true
  end

  describe "POST /solution/me_too" do
    it "requires login" do
      post "/solution/me_too.json", params: { topic_id: topic.id }
      expect(response.status).to eq(403)
    end

    context "when logged in" do
      before { sign_in(acting_user) }

      it "creates a me-too record and returns updated counts" do
        expect { post "/solution/me_too.json", params: { topic_id: topic.id } }.to change {
          DiscourseSolved::TopicMeToo.count
        }.by(1)
        expect(response.status).to eq(200)
        body = response.parsed_body
        expect(body["count"]).to eq(2)
        expect(body["user_did_me_too"]).to eq(true)
      end

      it "toggles the me-too off when called twice" do
        post "/solution/me_too.json", params: { topic_id: topic.id }
        expect { post "/solution/me_too.json", params: { topic_id: topic.id } }.to change {
          DiscourseSolved::TopicMeToo.count
        }.by(-1)
        expect(response.parsed_body["user_did_me_too"]).to eq(false)
      end

      it "rejects when the policy fails" do
        SiteSetting.enable_solved_me_too = false
        post "/solution/me_too.json", params: { topic_id: topic.id }
        expect(response.status).to eq(403)
      end

      it "returns 404 for unknown topic" do
        post "/solution/me_too.json", params: { topic_id: -1 }
        expect(response.status).to eq(404)
      end
    end
  end
end
