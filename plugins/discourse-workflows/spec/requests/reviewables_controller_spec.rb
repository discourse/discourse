# frozen_string_literal: true

RSpec.describe ReviewablesController do
  fab!(:admin)
  fab!(:workflow, :discourse_workflows_workflow)
  fab!(:other_workflow, :discourse_workflows_workflow)
  fab!(:post_reviewable, :reviewable_flagged_post)
  fab!(:user_reviewable, :reviewable_user)
  fab!(:unrelated_reviewable, :reviewable_queued_post)

  describe "#index" do
    before do
      sign_in(admin)
      post_reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:needs_approval],
        context: "discourse_workflows:workflow:#{workflow.id}",
        force_review: true,
      )
      user_reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:needs_approval],
        context: "discourse_workflows:workflow:#{other_workflow.id}",
        force_review: true,
      )
    end

    it "adds workflows to Type and current workflow names to Reason" do
      workflow.update!(name: "Renamed workflow")

      get "/review.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("meta", "reviewable_types")).to include(
        "discourse_workflows:workflow",
      )
      expect(response.parsed_body.dig("meta", "score_types")).to include(
        { "id" => "discourse_workflows:workflow:#{workflow.id}", "name" => workflow.name },
        {
          "id" => "discourse_workflows:workflow:#{other_workflow.id}",
          "name" => other_workflow.name,
        },
      )
    end

    it "filters posts and users by workflow Type" do
      get "/review.json", params: { type: "discourse_workflows:workflow" }

      expect(response.status).to eq(200)
      expect(
        response.parsed_body["reviewables"].map { |reviewable| reviewable["id"] },
      ).to contain_exactly(post_reviewable.id, user_reviewable.id)
    end

    it "filters by workflow Reason after the workflow is renamed" do
      workflow.update!(name: "Renamed workflow")

      get "/review.json",
          params: {
            type: "discourse_workflows:workflow",
            score_type: "discourse_workflows:workflow:#{workflow.id}",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["reviewables"].map { |reviewable| reviewable["id"] }).to eq(
        [post_reviewable.id],
      )

      get "/review.json",
          params: {
            score_type: "discourse_workflows:workflow:#{other_workflow.id}",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["reviewables"].map { |reviewable| reviewable["id"] }).to eq(
        [user_reviewable.id],
      )
    end

    it "hides workflow filters when the plugin is disabled" do
      SiteSetting.enable_discourse_workflows = false

      get "/review.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("meta", "reviewable_types")).not_to include(
        "discourse_workflows:workflow",
      )
      expect(response.parsed_body.dig("meta", "score_types")).not_to include(
        { "id" => "discourse_workflows:workflow:#{workflow.id}", "name" => workflow.name },
      )
    end

    it "ignores malformed workflow IDs" do
      [true, [workflow.id], { id: workflow.id }, 0, 1.9, "1 OR 1=1 --"].each do |workflow_id|
        get "/review.json", params: { additional_filters: { workflow_id: }.to_json }

        expect(response.status).to eq(200)
        expect(
          response.parsed_body["reviewables"].map { |reviewable| reviewable["id"] },
        ).to contain_exactly(post_reviewable.id, user_reviewable.id, unrelated_reviewable.id)
      end
    end
  end
end
