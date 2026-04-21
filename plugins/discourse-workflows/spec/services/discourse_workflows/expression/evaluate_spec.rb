# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Expression::Evaluate do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:template) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)

    let(:params) { { template: "Hello world" } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { template: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when workflow_id references a missing workflow" do
      let(:params) { { template: "Hello", workflow_id: -1 } }

      it "ignores the missing workflow and still resolves segments" do
        expect(result).to run_successfully
        expect(result[:workflow]).to be_nil
        expect(result[:segments]).to eq([{ kind: "plaintext", text: "Hello" }])
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "builds the preview context" do
        expect(result[:preview_context]).to include("$json" => {}, "trigger" => {})
      end

      it "returns resolved segments" do
        expect(result[:segments]).to eq([{ kind: "plaintext", text: "Hello world" }])
      end
    end

    context "with a workflow_id" do
      fab!(:workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:topic_created", name: "Topic created"
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
      end

      let(:params) { { template: "{{ $json.topic.title }}", workflow_id: workflow.id } }

      it "delegates to BuildExpressionPreviewContext" do
        DiscourseWorkflows::Workflow::Action::BuildExpressionPreviewContext
          .expects(:call)
          .with(workflow: workflow, node_id: nil)
          .returns({ "$json" => { "topic" => { "title" => "" } }, "trigger" => {} })
          .once

        expect(result).to run_successfully
      end

      it "resolves expressions against the preview context" do
        expect(result).to run_successfully
        expect(result[:segments].first[:state]).to eq("valid")
      end
    end
  end
end
