# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::List do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:user)

    let(:params) { {} }

    before { SiteSetting.discourse_workflows_enabled = true }

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
      fab!(:workflow_a, :discourse_workflows_workflow) do
        Fabricate(:discourse_workflows_workflow, name: "Alpha", created_by: user)
      end
      fab!(:workflow_b, :discourse_workflows_workflow) do
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

      fab!(:workflow_1, :discourse_workflows_workflow) do
        Fabricate(:discourse_workflows_workflow, name: "First", created_by: user)
      end
      fab!(:workflow_2, :discourse_workflows_workflow) do
        Fabricate(:discourse_workflows_workflow, name: "Second", created_by: user)
      end
      fab!(:workflow_3, :discourse_workflows_workflow) do
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
  end
end
