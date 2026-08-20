# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::PreviewNode do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:node_id) }

    it "rejects parameters that are not a hash" do
      contract = described_class.new(parameters: "junk")

      contract.validate

      expect(contract.errors[:parameters]).to be_present
    end

    it "accepts absent or hash parameters" do
      expect(described_class.new(workflow_id: 1, node_id: "a").validate).to eq(true)
      expect(
        described_class.new(workflow_id: 1, node_id: "a", parameters: { "x" => 1 }).validate,
      ).to eq(true)
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, guardian:) }

    fab!(:admin)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

    let(:guardian) { admin.guardian }
    let(:params) { { workflow_id: workflow.id, node_id: "summarize" } }

    let(:nodes) do
      [
        {
          "id" => "manual",
          "type" => "trigger:manual",
          "typeVersion" => "1.0",
          "name" => "Manual",
          "parameters" => {
          },
        },
        {
          "id" => "summarize",
          "type" => "action:summarize",
          "typeVersion" => "1.0",
          "name" => "Summarize",
          "parameters" => {
            "fields_to_split_by" => "topic_id",
            "fields_to_summarize" => {
              "values" => [
                { "aggregation" => "sum", "field" => "likes", "output_field_name" => "total" },
              ],
            },
          },
        },
        {
          "id" => "create-post",
          "type" => "action:post",
          "typeVersion" => "1.0",
          "name" => "Create post",
          "parameters" => {
            "operation" => "create",
          },
        },
      ]
    end

    let(:connections) do
      { "Manual" => { "main" => [[{ "node" => "Summarize", "type" => "main", "index" => 0 }]] } }
    end

    before do
      workflow.update!(nodes: nodes, connections: connections)
      workflow.update!(
        pin_data: {
          "Manual" => [
            { "json" => { "topic_id" => 7, "likes" => 4 } },
            { "json" => { "topic_id" => 7, "likes" => 5 } },
            { "json" => { "topic_id" => 8, "likes" => 2 } },
          ],
        },
      )
    end

    it "runs the node against pinned upstream data" do
      expect(result).to be_a_success
      expect(result.output[:input_count]).to eq(3)
      expect(result.output[:outputs].first.map { |item| item["json"] }).to eq(
        [{ "topic_id" => 7, "total" => 9 }, { "topic_id" => 8, "total" => 2 }],
      )
    end

    it "reflects parameters supplied by the editor rather than the saved ones" do
      params[:parameters] = {
        "fields_to_split_by" => "",
        "fields_to_summarize" => {
          "values" => [{ "aggregation" => "count", "output_field_name" => "rows" }],
        },
      }

      expect(result.output[:outputs].first.map { |item| item["json"] }).to eq([{ "rows" => 3 }])
    end

    it "fails the contract when parameters is not a hash" do
      params[:parameters] = "junk"

      expect(result).to fail_a_contract
    end

    it "refuses to preview a node type that is not previewable" do
      params[:node_id] = "create-post"

      expect(result).to fail_a_policy(:node_type_previewable)
    end

    it "returns the node's error instead of raising" do
      params[:parameters] = { "fields_to_summarize" => { "values" => [] } }

      expect(result).to be_a_success
      expect(result.output[:error]).to match(/No aggregations configured/)
      expect(result.output[:outputs]).to eq([])
    end

    context "when the node fails unexpectedly" do
      before do
        allow_any_instance_of(DiscourseWorkflows::Nodes::Summarize::V1).to receive(
          :execute,
        ).and_raise(StandardError, "secret internals")
      end

      it "returns a generic message rather than the exception's" do
        expect(result).to be_a_success
        expect(result.output[:error]).to eq(
          I18n.t("discourse_workflows.errors.node_preview_failed"),
        )
        expect(result.output[:outputs]).to eq([])
      end
    end

    it "fails when the node is not in the workflow" do
      params[:node_id] = "nope"

      expect(result).to fail_to_find_a_model(:node)
    end

    it "truncates long output and says so" do
      workflow.update!(
        pin_data: {
          "Manual" => (1..40).map { |n| { "json" => { "topic_id" => n, "likes" => 1 } } },
        },
      )

      expect(result.output[:outputs].first.length).to eq(
        DiscourseWorkflows::Workflow::Action::RunNodePreview::MAX_ITEMS,
      )
      expect(result.output[:truncated]).to eq(true)
    end
  end
end
