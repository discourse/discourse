# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Action::BuildExpressionPreviewContext do
  subject(:context) { described_class.call(workflow: workflow, node_id: node_id) }

  fab!(:admin)

  let(:node_id) { nil }

  describe ".call" do
    context "without a workflow" do
      let(:workflow) { nil }

      it "returns the default context" do
        expect(context).to eq({ "$json" => {}, "trigger" => {} })
      end

      it "does not include execution metadata" do
        expect(context).not_to have_key("__execution")
      end
    end

    context "with a workflow" do
      fab!(:workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:topic_created", name: "Topic created"
            g.node "action-1", "action:topic_tags", name: "Tag topic"
            g.chain "trigger-1", "action-1"
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
      end

      it "includes initial execution metadata" do
        expect(context["__execution"]).to include(
          "id" => 0,
          "workflow_id" => workflow.id,
          "workflow_name" => workflow.name,
        )
      end

      it "populates trigger exemplar into trigger and $json" do
        expect(context["trigger"]).to include("topic")
        expect(context["$json"]).to eq(context["trigger"])
      end

      it "populates exemplars keyed by node name" do
        expect(context["Topic created"]).to be_an(Array)
        expect(context["Topic created"].first).to include("json")
      end

      context "when node_id is provided" do
        let(:node_id) { "action-1" }

        it "uses the upstream node's exemplar for $json" do
          expect(context["$json"]).to include("topic")
        end

        it "keeps the trigger exemplar separate from $json" do
          expect(context["trigger"]).to include("topic")
        end
      end

      context "when node_id has no upstream" do
        let(:node_id) { "trigger-1" }

        it "leaves $json as the default empty hash" do
          expect(context["$json"]).to eq({})
        end
      end

      context "when a node has an unregistered type" do
        fab!(:workflow) do
          graph =
            build_workflow_graph do |g|
              g.node "trigger-1", "trigger:topic_created", name: "Topic created"
              g.node "mystery-1", "action:does_not_exist", name: "Mystery"
            end
          Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
        end

        it "skips that node without failing" do
          expect(context).not_to have_key("Mystery")
          expect(context["Topic created"]).to be_an(Array)
        end
      end

      context "when a node has no name" do
        fab!(:workflow) do
          graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:topic_created", name: "" }
          Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
        end

        it "does not add an entry for the empty name" do
          expect(context.keys).not_to include("")
        end

        it "still populates the trigger exemplar" do
          expect(context["trigger"]).to include("topic")
        end
      end

      context "with a last successful execution" do
        fab!(:execution) do
          Fabricate(:discourse_workflows_execution, workflow: workflow, status: :success)
        end

        context "without execution_data" do
          it "sets the execution id on metadata" do
            expect(context["__execution"]["id"]).to eq(execution.id)
          end

          it "leaves schema exemplars untouched" do
            expect(context["trigger"]).to include("topic")
          end
        end

        context "with a successful trigger step" do
          before do
            Fabricate(
              :discourse_workflows_execution_data,
              execution: execution,
              data: {
                entries: {
                  "Topic created" => [
                    {
                      "status" => "success",
                      "node_type" => "trigger:topic_created",
                      "output_items" => [{ "json" => { "title" => "From past run" } }],
                    },
                  ],
                },
              }.to_json,
            )
          end

          it "overlays the trigger json into trigger and $json" do
            expect(context["trigger"]).to eq({ "title" => "From past run" })
            expect(context["$json"]).to eq({ "title" => "From past run" })
          end

          it "overlays the step json under the node name" do
            expect(context["Topic created"]).to eq([{ "json" => { "title" => "From past run" } }])
          end

          it "updates the execution id" do
            expect(context["__execution"]["id"]).to eq(execution.id)
          end
        end

        context "with a successful non-trigger step" do
          before do
            Fabricate(
              :discourse_workflows_execution_data,
              execution: execution,
              data: {
                entries: {
                  "Tag topic" => [
                    {
                      "status" => "success",
                      "node_type" => "action:topic_tags",
                      "output_items" => [{ "json" => { "tagged" => true } }],
                    },
                  ],
                },
              }.to_json,
            )
          end

          it "overlays the step json under the node name" do
            expect(context["Tag topic"]).to eq([{ "json" => { "tagged" => true } }])
          end

          it "does not overwrite $json when there is no node_id" do
            expect(context["$json"]).to include("topic")
          end

          context "when node_id targets the action's downstream" do
            let(:node_id) { "action-1" }

            it "still uses the upstream exemplar for $json since the upstream name does not match" do
              expect(context["$json"]).to include("topic")
            end
          end
        end

        context "with a step using legacy items key" do
          before do
            Fabricate(
              :discourse_workflows_execution_data,
              execution: execution,
              data: {
                entries: {
                  "Topic created" => [
                    {
                      "status" => "success",
                      "node_type" => "trigger:topic_created",
                      "items" => [{ "json" => { "title" => "Legacy items" } }],
                    },
                  ],
                },
              }.to_json,
            )
          end

          it "reads json from items when output_items is missing" do
            expect(context["trigger"]).to eq({ "title" => "Legacy items" })
          end
        end

        context "with no successful step in the entry" do
          before do
            Fabricate(
              :discourse_workflows_execution_data,
              execution: execution,
              data: {
                entries: {
                  "Topic created" => [
                    {
                      "status" => "error",
                      "node_type" => "trigger:topic_created",
                      "output_items" => [{ "json" => { "title" => "Should not appear" } }],
                    },
                  ],
                },
              }.to_json,
            )
          end

          it "does not overlay the failed step" do
            expect(context["Topic created"]).not_to eq(
              [{ "json" => { "title" => "Should not appear" } }],
            )
          end

          it "preserves the schema exemplar for the node" do
            expect(context["Topic created"].first["json"]).to include("topic")
          end
        end

        context "with empty output items" do
          before do
            Fabricate(
              :discourse_workflows_execution_data,
              execution: execution,
              data: {
                entries: {
                  "Topic created" => [
                    {
                      "status" => "success",
                      "node_type" => "trigger:topic_created",
                      "output_items" => [],
                    },
                  ],
                },
              }.to_json,
            )
          end

          it "falls back to an empty hash for json" do
            expect(context["Topic created"]).to eq([{ "json" => {} }])
          end
        end

        context "when node_id matches a node whose upstream has successful execution data" do
          let(:node_id) { "action-1" }

          before do
            Fabricate(
              :discourse_workflows_execution_data,
              execution: execution,
              data: {
                entries: {
                  "Topic created" => [
                    {
                      "status" => "success",
                      "node_type" => "trigger:topic_created",
                      "output_items" => [{ "json" => { "title" => "Upstream run" } }],
                    },
                  ],
                },
              }.to_json,
            )
          end

          it "overlays $json with the upstream's executed output" do
            expect(context["$json"]).to eq({ "title" => "Upstream run" })
          end
        end
      end
    end
  end
end
