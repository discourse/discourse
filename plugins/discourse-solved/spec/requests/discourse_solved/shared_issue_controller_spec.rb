# frozen_string_literal: true

RSpec.describe DiscourseSolved::SharedIssueController do
  fab!(:author, :user)
  fab!(:acting_user, :user)
  fab!(:category) do
    Fabricate(:category).tap do |c|
      c.upsert_custom_fields(DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD => "true")
    end
  end
  fab!(:topic) { Fabricate(:topic, category:, user: author) }
  fab!(:post_1, :post) { Fabricate(:post, topic:) }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.enable_solved_shared_issues = true
    DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
  end

  describe "POST /solution/shared_issue" do
    it "requires login" do
      post "/solution/shared_issue.json", params: { topic_id: topic.id }
      expect(response.status).to eq(403)
    end

    context "when logged in" do
      before { sign_in(acting_user) }

      it "creates a shared issue record and returns updated counts" do
        expect { post "/solution/shared_issue.json", params: { topic_id: topic.id } }.to change {
          DiscourseSolved::SharedIssue.count
        }.by(1)
        expect(response.status).to eq(200)
        body = response.parsed_body
        expect(body["count"]).to eq(1)
        expect(body["user_created_shared_issue"]).to eq(true)
      end

      it "toggles the shared issue off when called twice" do
        post "/solution/shared_issue.json", params: { topic_id: topic.id }
        expect { post "/solution/shared_issue.json", params: { topic_id: topic.id } }.to change {
          DiscourseSolved::SharedIssue.count
        }.by(-1)
        expect(response.parsed_body["user_created_shared_issue"]).to eq(false)
      end

      it "rejects when the policy fails" do
        SiteSetting.enable_solved_shared_issues = false
        post "/solution/shared_issue.json", params: { topic_id: topic.id }
        expect(response.status).to eq(403)
      end

      it "rejects when the topic is not in a support category" do
        other_topic = Fabricate(:topic, user: author)
        post "/solution/shared_issue.json", params: { topic_id: other_topic.id }
        expect(response.status).to eq(403)
      end

      it "rejects when shared issues are disabled for the category" do
        category.upsert_custom_fields(
          DiscourseSolved::SHARED_ISSUES_ENABLED_CUSTOM_FIELD => "false",
        )
        post "/solution/shared_issue.json", params: { topic_id: topic.id }
        expect(response.status).to eq(403)
      end

      it "returns 404 for unknown topic" do
        post "/solution/shared_issue.json", params: { topic_id: -1 }
        expect(response.status).to eq(404)
      end
    end
  end
end
