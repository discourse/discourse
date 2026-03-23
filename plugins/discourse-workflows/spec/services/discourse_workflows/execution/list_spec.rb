# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::List do
  describe ".call" do
    subject(:result) { described_class.call(params:) }

    let(:params) { {} }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when there are no executions" do
      it { is_expected.to run_successfully }

      it "returns an empty collection" do
        expect(result[:executions]).to be_empty
      end

      it "returns zero total rows" do
        expect(result[:total_rows]).to eq(0)
      end

      it "does not return a load more url" do
        expect(result[:load_more_url]).to be_nil
      end
    end

    context "when there are executions" do
      fab!(:workflow, :discourse_workflows_workflow)
      fab!(:execution_a, :discourse_workflows_execution) do
        Fabricate(:discourse_workflows_execution, workflow: workflow)
      end
      fab!(:execution_b, :discourse_workflows_execution) do
        Fabricate(:discourse_workflows_execution, workflow: workflow)
      end

      it { is_expected.to run_successfully }

      it "returns executions ordered by id descending" do
        expect(result[:executions].map(&:id)).to eq([execution_b.id, execution_a.id])
      end

      it "returns the total count" do
        expect(result[:total_rows]).to eq(2)
      end
    end

    context "with pagination" do
      let(:params) { { limit: 2 } }

      fab!(:workflow, :discourse_workflows_workflow)
      fab!(:execution_1, :discourse_workflows_execution) do
        Fabricate(:discourse_workflows_execution, workflow: workflow)
      end
      fab!(:execution_2, :discourse_workflows_execution) do
        Fabricate(:discourse_workflows_execution, workflow: workflow)
      end
      fab!(:execution_3, :discourse_workflows_execution) do
        Fabricate(:discourse_workflows_execution, workflow: workflow)
      end

      it "returns only the requested number of executions" do
        expect(result[:executions].size).to eq(2)
      end

      it "returns a load more url with cursor" do
        last_id = result[:executions].last.id
        expect(result[:load_more_url]).to eq(
          "/admin/plugins/discourse-workflows/executions.json?cursor=#{last_id}&limit=2",
        )
      end

      context "when using a cursor" do
        let(:params) { { limit: 2, cursor: execution_3.id } }

        it "returns executions after the cursor" do
          expect(result[:executions].map(&:id)).to eq([execution_2.id, execution_1.id])
        end

        it "does not return a load more url when no more results" do
          expect(result[:load_more_url]).to be_nil
        end
      end
    end

    context "when scoped to a workflow" do
      fab!(:workflow_a, :discourse_workflows_workflow)
      fab!(:workflow_b, :discourse_workflows_workflow)
      fab!(:execution_a, :discourse_workflows_execution) do
        Fabricate(:discourse_workflows_execution, workflow: workflow_a)
      end
      fab!(:execution_b, :discourse_workflows_execution) do
        Fabricate(:discourse_workflows_execution, workflow: workflow_b)
      end

      let(:params) { { workflow_id: workflow_a.id } }

      it "returns only executions for the specified workflow" do
        expect(result[:executions].map(&:id)).to eq([execution_a.id])
      end

      it "returns the scoped total count" do
        expect(result[:total_rows]).to eq(1)
      end

      it "includes workflow_id in load more url" do
        # Only 1 result, no load_more
        expect(result[:load_more_url]).to be_nil
      end
    end
  end
end
