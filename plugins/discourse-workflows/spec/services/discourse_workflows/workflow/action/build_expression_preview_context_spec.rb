# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Action::BuildExpressionPreviewContext do
  subject(:context) { described_class.call(workflow: workflow, node_id: node_id) }

  fab!(:admin)

  let(:node_id) { nil }

  def run_data_for(
    node_id,
    node_name:,
    node_type:,
    items:,
    inputs: nil,
    outputs: nil,
    status: "success"
  )
    {
      node_name => [
        {
          "node_id" => node_id.to_s,
          "node_name" => node_name,
          "node_type" => node_type,
          "status" => status,
          "run_index" => 0,
          "inputs" => inputs || [],
          "outputs" =>
            outputs || [{ "index" => 0, "items" => items, "item_count" => items.length }],
        },
      ],
    }
  end

  describe ".call" do
    context "without a workflow" do
      let(:workflow) { nil }

      it "returns the default context" do
        expect(context).to eq({ "$json" => {}, "$trigger" => {} })
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

      it "includes initial execution metadata and node lookup data" do
        expect(context["__execution"]).to include(
          "id" => 0,
          "workflow_id" => workflow.id,
          "workflow_name" => workflow.name,
        )
        expect(context["__node_parameters_by_name"]).to include("Tag topic" => {})
      end

      it "does not create output exemplars without execution data" do
        expect(context["$json"]).to eq({})
        expect(context["$trigger"]).to eq({})
        expect(context).not_to have_key("Topic created")
      end

      context "when node_id is provided" do
        let(:node_id) { "action-1" }

        it "sets the current node id for expression resolution" do
          expect(context["__current_node_id"]).to eq("action-1")
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
        end

        context "with a successful trigger run" do
          let(:items) { [{ "json" => { "title" => "From past run" } }] }

          before do
            Fabricate(
              :discourse_workflows_execution_data,
              execution: execution,
              data: {
                "entries" => {
                },
                "context" => {
                },
                "node_contexts" => {
                },
                "run_data" =>
                  run_data_for(
                    "trigger-1",
                    node_name: "Topic created",
                    node_type: "trigger:topic_created",
                    items: items,
                  ),
              },
            )
          end

          it "overlays the trigger json into trigger and $json" do
            expect(context["$trigger"]).to eq({ "title" => "From past run" })
            expect(context["$json"]).to eq({ "title" => "From past run" })
          end

          it "overlays the run items under the node name" do
            expect(context["Topic created"]).to eq(items)
          end

          it "exposes node runs in the expression resolver shape" do
            expect(context.dig("__node_runs", "Topic created", 0, "outputs", 0)).to eq(items)
          end

          context "when the current node has no recorded input data" do
            let(:node_id) { "action-1" }

            it "uses the connected upstream output for input context" do
              expect(context["$json"]).to eq({ "title" => "From past run" })
              expect(context["__input_item"]).to eq(items.first)
              expect(context["__input_items"]).to eq(items)
              expect(context["__input_sources"]).to eq(
                [{ "node_name" => "Topic created", "output_index" => 0 }],
              )
            end
          end

          context "when the current node only has a skipped run" do
            let(:node_id) { "action-1" }

            before do
              execution.execution_data.update!(
                data: {
                  "entries" => {
                  },
                  "context" => {
                  },
                  "node_contexts" => {
                  },
                  "run_data" =>
                    run_data_for(
                      "trigger-1",
                      node_name: "Topic created",
                      node_type: "trigger:topic_created",
                      items: items,
                    ).deep_merge(
                      run_data_for(
                        "action-1",
                        node_name: "Tag topic",
                        node_type: "action:topic_tags",
                        items: items,
                        status: "skipped",
                      ),
                    ),
                },
              )
            end

            it "uses the connected upstream output for input context" do
              expect(context["$json"]).to eq({ "title" => "From past run" })
              expect(context["__input_item"]).to eq(items.first)
              expect(context["__input_items"]).to eq(items)
              expect(context["__input_sources"]).to eq(
                [{ "node_name" => "Topic created", "output_index" => 0 }],
              )
            end
          end

          context "when the current node has recorded input data" do
            let(:node_id) { "action-1" }
            let(:current_items) { [{ "json" => { "title" => "From current input" } }] }

            before do
              execution.execution_data.update!(
                data: {
                  "entries" => {
                  },
                  "context" => {
                  },
                  "node_contexts" => {
                  },
                  "run_data" =>
                    run_data_for(
                      "trigger-1",
                      node_name: "Topic created",
                      node_type: "trigger:topic_created",
                      items: items,
                    ).deep_merge(
                      run_data_for(
                        "action-1",
                        node_name: "Tag topic",
                        node_type: "action:topic_tags",
                        items: [],
                        inputs: [
                          {
                            "index" => 0,
                            "items" => current_items,
                            "item_count" => current_items.length,
                            "source" => {
                              "node_name" => "Topic created",
                              "output_index" => 0,
                            },
                          },
                        ],
                      ),
                    ),
                },
              )
            end

            it "uses the current node input for $json" do
              expect(context["$json"]).to eq({ "title" => "From current input" })
              expect(context["__input_item"]).to eq(current_items.first)
              expect(context["__input_items"]).to eq(current_items)
              expect(context["__input_sources"]).to eq(
                [{ "node_name" => "Topic created", "output_index" => 0 }],
              )
            end
          end

          context "when recorded input came from another source" do
            let(:node_id) { "action-1" }
            let(:stale_items) { [{ "json" => { "reviewable" => { "id" => 1 } } }] }

            before do
              execution.execution_data.update!(
                data: {
                  "entries" => {
                  },
                  "context" => {
                  },
                  "node_contexts" => {
                  },
                  "run_data" =>
                    run_data_for(
                      "trigger-1",
                      node_name: "Topic created",
                      node_type: "trigger:topic_created",
                      items: items,
                    ).deep_merge(
                      run_data_for(
                        "action-1",
                        node_name: "Tag topic",
                        node_type: "action:topic_tags",
                        items: [],
                        inputs: [
                          {
                            "index" => 0,
                            "items" => stale_items,
                            "item_count" => stale_items.length,
                            "source" => {
                              "node_name" => "Approved reviewable",
                              "output_index" => 0,
                            },
                          },
                        ],
                      ),
                    ),
                },
              )
            end

            it "uses the default input context" do
              expect(context["$json"]).to eq({})
            end
          end
        end

        context "when the current node is connected to a non-primary upstream output" do
          subject(:context) do
            described_class.call(workflow: branched_workflow, node_id: "action-1")
          end

          let(:primary_items) { [{ "json" => { "matched" => true } }] }
          let(:rejected_items) { [{ "json" => { "matched" => false } }] }

          fab!(:branched_workflow) do
            graph =
              build_workflow_graph do |g|
                g.node "filter-1", "condition:filter", name: "Filter"
                g.node "action-1", "action:log", name: "Log"
                g.connect "filter-1", "action-1", output: "false"
              end
            Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
          end

          before do
            Fabricate(
              :discourse_workflows_execution_data,
              execution:
                Fabricate(
                  :discourse_workflows_execution,
                  workflow: branched_workflow,
                  status: :success,
                ),
              data: {
                "entries" => {
                },
                "context" => {
                },
                "node_contexts" => {
                },
                "run_data" =>
                  run_data_for(
                    "filter-1",
                    node_name: "Filter",
                    node_type: "condition:filter",
                    items: primary_items,
                    outputs: [
                      {
                        "index" => 0,
                        "items" => primary_items,
                        "item_count" => primary_items.length,
                      },
                      {
                        "index" => 1,
                        "items" => rejected_items,
                        "item_count" => rejected_items.length,
                      },
                    ],
                  ).deep_merge(
                    run_data_for(
                      "action-1",
                      node_name: "Log",
                      node_type: "action:log",
                      items: [],
                      inputs: [
                        {
                          "index" => 0,
                          "items" => rejected_items,
                          "item_count" => rejected_items.length,
                          "source" => {
                            "node_name" => "Filter",
                            "output_index" => 1,
                          },
                        },
                      ],
                    ),
                  ),
              },
            )
          end

          it "uses the connected output for current-node input context" do
            expect(context["$json"]).to eq({ "matched" => false })
            expect(context["__input_item"]).to eq(rejected_items.first)
            expect(context["__input_items"]).to eq(rejected_items)
            expect(context["__input_sources"]).to eq(
              [{ "node_name" => "Filter", "output_index" => 1 }],
            )
            expect(context.dig("__node_runs", "Filter", 0, "outputs", 1)).to eq(rejected_items)
          end
        end

        context "with a successful non-trigger run" do
          before do
            Fabricate(
              :discourse_workflows_execution_data,
              execution: execution,
              data: {
                "entries" => {
                },
                "context" => {
                },
                "node_contexts" => {
                },
                "run_data" =>
                  run_data_for(
                    "action-1",
                    node_name: "Tag topic",
                    node_type: "action:topic_tags",
                    items: [{ "json" => { "tagged" => true } }],
                  ),
              },
            )
          end

          it "overlays the run items under the node name" do
            expect(context["Tag topic"]).to eq([{ "json" => { "tagged" => true } }])
          end

          it "does not overwrite $json when there is no node_id" do
            expect(context["$json"]).to eq({})
          end
        end

        context "with no successful run" do
          before do
            Fabricate(
              :discourse_workflows_execution_data,
              execution: execution,
              data: {
                "entries" => {
                },
                "context" => {
                },
                "node_contexts" => {
                },
                "run_data" =>
                  run_data_for(
                    "trigger-1",
                    node_name: "Topic created",
                    node_type: "trigger:topic_created",
                    items: [{ "json" => { "title" => "Should not appear" } }],
                    status: "error",
                  ),
              },
            )
          end

          it "does not overlay failed run data" do
            expect(context["Topic created"]).to be_nil
            expect(context["$json"]).to eq({})
          end
        end
      end
    end
  end
end
