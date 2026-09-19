# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::List do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(limit: limit) }

    context "when limit is within bounds" do
      let(:limit) { 50 }

      it "keeps the provided limit" do
        contract.valid?
        expect(contract.limit).to eq(50)
      end
    end

    context "when limit exceeds maximum" do
      let(:limit) { 200 }

      it "clamps to MAX_LIMIT" do
        contract.valid?
        expect(contract.limit).to eq(DiscourseWorkflows::Pagination::MAX_LIMIT)
      end
    end

    context "when limit is below minimum" do
      let(:limit) { 0 }

      it "clamps to 1" do
        contract.valid?
        expect(contract.limit).to eq(1)
      end
    end

    context "when limit is not provided" do
      let(:limit) { nil }

      it "leaves limit as nil" do
        contract.valid?
        expect(contract.limit).to be_nil
      end
    end

    describe "#effective_limit" do
      context "when limit is set" do
        let(:limit) { 10 }

        it "returns the set limit" do
          contract.valid?
          expect(contract.effective_limit).to eq(10)
        end
      end

      context "when limit is nil" do
        let(:limit) { nil }

        it "returns the default limit" do
          expect(contract.effective_limit).to eq(DiscourseWorkflows::Pagination::DEFAULT_LIMIT)
        end
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow, :discourse_workflows_workflow)

    let(:params) { {} }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when there are no executions" do
      it { is_expected.to run_successfully }

      it "returns an empty collection" do
        expect(result[:executions]).to be_empty
      end

      it "does not return a load more url" do
        expect(result[:load_more_url]).to be_nil
      end
    end

    context "when there are executions" do
      fab!(:execution_a) { Fabricate(:discourse_workflows_execution, workflow: workflow) }
      fab!(:execution_b) { Fabricate(:discourse_workflows_execution, workflow: workflow) }

      it { is_expected.to run_successfully }

      it "returns executions ordered by id descending" do
        expect(result[:executions].map(&:id)).to eq([execution_b.id, execution_a.id])
      end
    end

    context "with pagination" do
      fab!(:execution_1) { Fabricate(:discourse_workflows_execution, workflow: workflow) }
      fab!(:execution_2) { Fabricate(:discourse_workflows_execution, workflow: workflow) }
      fab!(:execution_3) { Fabricate(:discourse_workflows_execution, workflow: workflow) }

      let(:params) { { limit: 2 } }

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
      fab!(:execution_a) { Fabricate(:discourse_workflows_execution, workflow: workflow_a) }
      fab!(:execution_b) { Fabricate(:discourse_workflows_execution, workflow: workflow_b) }

      let(:params) { { workflow_id: workflow_a.id } }

      it "returns only executions for the specified workflow" do
        expect(result[:executions].map(&:id)).to eq([execution_a.id])
      end

      context "with pagination" do
        fab!(:execution_c) { Fabricate(:discourse_workflows_execution, workflow: workflow_a) }
        fab!(:execution_d) { Fabricate(:discourse_workflows_execution, workflow: workflow_a) }

        let(:params) { { workflow_id: workflow_a.id, limit: 1 } }

        it "returns a workflow-scoped load more url" do
          last_id = result[:executions].last.id
          expect(result[:load_more_url]).to include(
            "/admin/plugins/discourse-workflows/workflows/#{workflow_a.id}/executions.json",
          )
          expect(result[:load_more_url]).to include("cursor=#{last_id}")
        end
      end
    end
  end
end
