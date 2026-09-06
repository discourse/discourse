# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowTag::List do
  describe ".call" do
    subject(:result) { described_class.call(**dependencies) }

    fab!(:admin)
    let(:dependencies) { { guardian: admin.guardian } }

    context "when user cannot manage workflows" do
      fab!(:user)
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when tags exist" do
      before do
        Fabricate(:discourse_workflows_workflow, created_by: admin, tags: %w[ops])
        Fabricate(:discourse_workflows_workflow, created_by: admin, tags: %w[ops billing])
      end

      it { is_expected.to run_successfully }

      it "returns tags ordered by name with workflow counts" do
        expect(
          result[:workflow_tags].map do |tag|
            [tag.name, tag.attributes["workflow_count_value"].to_i]
          end,
        ).to eq([["billing", 1], ["ops", 2]])
      end
    end

    context "when there are no tags" do
      it { is_expected.to run_successfully }

      it "returns an empty list" do
        expect(result[:workflow_tags]).to eq([])
      end
    end
  end
end
