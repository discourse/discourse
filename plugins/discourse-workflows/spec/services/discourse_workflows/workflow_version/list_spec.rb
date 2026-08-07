# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowVersion::List do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

    let(:params) { { workflow_id: workflow.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when the contract is invalid" do
      let(:params) { { workflow_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when the workflow is not found" do
      let(:params) { { workflow_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when the user cannot manage workflows" do
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "returns versions newest first with the total count" do
        second_version = workflow.snapshot!(user: admin)

        expect(result[:versions].map(&:version_number)).to eq([2, 1])
        expect(result[:versions].first.version_id).to eq(second_version.version_id)
        expect(result[:total_rows]).to eq(2)
      end

      it "does not return a load more url when all results fit" do
        expect(result[:load_more_url]).to be_nil
      end
    end

    context "with pagination" do
      let(:params) { { workflow_id: workflow.id, limit: 1 } }

      before { workflow.snapshot!(user: admin) } # version 2

      it "returns only the requested number of versions" do
        expect(result[:versions].size).to eq(1)
      end

      it "returns a load more url keyed on version_number" do
        expect(result[:load_more_url]).to eq(
          "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/versions.json?cursor=2&limit=1",
        )
      end

      it "returns the total count of all versions" do
        expect(result[:total_rows]).to eq(2)
      end

      context "when using a cursor" do
        let(:params) { { workflow_id: workflow.id, limit: 10, cursor: 2 } }

        it "returns versions before the cursor" do
          expect(result[:versions].map(&:version_number)).to eq([1])
        end
      end
    end

    context "when other workflows have versions" do
      fab!(:other_workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

      it "only returns versions for the requested workflow" do
        other_workflow.snapshot!(user: admin)

        expect(result[:versions].map(&:workflow_id).uniq).to eq([workflow.id])
      end
    end
  end
end
