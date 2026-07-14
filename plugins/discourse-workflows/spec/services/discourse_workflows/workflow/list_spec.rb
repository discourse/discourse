# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::List do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)

    let(:params) { {} }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when user cannot manage workflows" do
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when there are no workflows" do
      it { is_expected.to run_successfully }

      it "returns an empty collection" do
        expect(result[:workflows]).to be_empty
      end

      it "returns zero total rows" do
        expect(result[:total_rows]).to eq(0)
      end

      it "does not return a load more url" do
        expect(result[:load_more_url]).to be_nil
      end
    end

    context "when there are workflows" do
      fab!(:workflow_a) do
        Fabricate(:discourse_workflows_workflow, name: "Alpha", created_by: user)
      end
      fab!(:workflow_b) do
        Fabricate(:discourse_workflows_workflow, name: "Bravo", created_by: user)
      end

      it { is_expected.to run_successfully }

      it "returns workflows ordered by id descending" do
        expect(result[:workflows].map(&:id)).to eq([workflow_b.id, workflow_a.id])
      end

      it "returns the total count" do
        expect(result[:total_rows]).to eq(2)
      end

      it "does not return a load more url when all results fit" do
        expect(result[:load_more_url]).to be_nil
      end
    end

    context "with pagination" do
      let(:params) { { limit: 2 } }

      fab!(:workflow_1) do
        Fabricate(:discourse_workflows_workflow, name: "First", created_by: user)
      end
      fab!(:workflow_2) do
        Fabricate(:discourse_workflows_workflow, name: "Second", created_by: user)
      end
      fab!(:workflow_3) do
        Fabricate(:discourse_workflows_workflow, name: "Third", created_by: user)
      end

      it "returns only the requested number of workflows" do
        expect(result[:workflows].size).to eq(2)
      end

      it "returns a load more url with cursor" do
        last_id = result[:workflows].last.id
        expect(result[:load_more_url]).to eq(
          "/admin/plugins/discourse-workflows/workflows.json?cursor=#{last_id}&limit=2",
        )
      end

      it "returns the total count of all workflows" do
        expect(result[:total_rows]).to eq(3)
      end

      context "when using a cursor" do
        let(:params) { { limit: 2, cursor: workflow_3.id } }

        it "returns workflows after the cursor" do
          expect(result[:workflows].map(&:id)).to eq([workflow_2.id, workflow_1.id])
        end

        it "does not return a load more url when no more results" do
          expect(result[:load_more_url]).to be_nil
        end
      end
    end

    context "with name filter" do
      fab!(:workflow_a) do
        Fabricate(:discourse_workflows_workflow, name: "Deploy to production", created_by: user)
      end
      fab!(:workflow_b) do
        Fabricate(:discourse_workflows_workflow, name: "Send notification", created_by: user)
      end

      let(:params) { { filter: "deploy" } }

      it { is_expected.to run_successfully }

      it "returns only matching workflows" do
        expect(result[:workflows].map(&:name)).to eq(["Deploy to production"])
      end

      it "returns filtered total rows" do
        expect(result[:total_rows]).to eq(1)
      end
    end

    context "with trigger_type filter" do
      fab!(:error_workflow) do
        graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:error" }
        Fabricate(:discourse_workflows_workflow, name: "Error handler", created_by: user, **graph)
      end
      fab!(:other_workflow) do
        Fabricate(:discourse_workflows_workflow, name: "Other", created_by: user)
      end

      let(:params) { { trigger_type: "error" } }

      it "returns only workflows with the specified trigger type" do
        expect(result[:workflows].map(&:name)).to eq(["Error handler"])
      end

      it "returns filtered total rows" do
        expect(result[:total_rows]).to eq(1)
      end
    end

    context "with pagination and filters" do
      let(:params) { { limit: 1, filter: "deploy" } }

      fab!(:workflow_1) do
        Fabricate(:discourse_workflows_workflow, name: "Deploy alpha", created_by: user)
      end
      fab!(:workflow_2) do
        Fabricate(:discourse_workflows_workflow, name: "Deploy beta", created_by: user)
      end
      fab!(:workflow_3) do
        Fabricate(:discourse_workflows_workflow, name: "Other workflow", created_by: user)
      end

      it "returns filtered total rows" do
        expect(result[:total_rows]).to eq(2)
      end

      it "includes filter params in load more url" do
        url = result[:load_more_url]
        expect(url).to include("filter=deploy")
        expect(url).to include("limit=1")
        expect(url).to include("cursor=")
      end
    end

    context "with exclude_id" do
      fab!(:workflow_a) do
        Fabricate(:discourse_workflows_workflow, name: "Alpha", created_by: user)
      end
      fab!(:workflow_b) do
        Fabricate(:discourse_workflows_workflow, name: "Bravo", created_by: user)
      end

      let(:params) { { exclude_id: workflow_a.id } }

      it "excludes the specified workflow" do
        expect(result[:workflows].map(&:name)).to eq(["Bravo"])
      end
    end
  end
end
