# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowTagsController do
  fab!(:admin)

  describe "GET /admin/plugins/discourse-workflows/workflow-tags" do
    context "when not logged in as admin" do
      fab!(:user)

      before { sign_in(user) }

      it "returns 404" do
        get "/admin/plugins/discourse-workflows/workflow-tags.json"

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when logged in as admin" do
      before { sign_in(admin) }

      it "returns the tags ordered by name with their workflow counts" do
        Fabricate(:discourse_workflows_workflow, created_by: admin, tags: %w[ops])
        Fabricate(:discourse_workflows_workflow, created_by: admin, tags: %w[ops billing])

        get "/admin/plugins/discourse-workflows/workflow-tags.json"

        expect(response).to have_http_status(:ok)
        expect(
          response.parsed_body["workflow_tags"].map { |tag| tag.slice("name", "workflow_count") },
        ).to eq(
          [
            { "name" => "billing", "workflow_count" => 1 },
            { "name" => "ops", "workflow_count" => 2 },
          ],
        )
      end

      it "returns an empty list when there are no tags" do
        get "/admin/plugins/discourse-workflows/workflow-tags.json"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["workflow_tags"]).to eq([])
      end
    end
  end
end
