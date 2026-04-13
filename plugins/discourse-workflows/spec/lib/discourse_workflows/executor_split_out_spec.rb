# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)

  describe "#run" do
    it "splits items then loops over them in batches" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "set-fields-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "json",
                   "include_input" => false,
                   "json" => '{"urls": ["a.png", "b.png", "c.png"]}',
                 }
          g.node "split-1",
                 "action:split_out",
                 name: "Split Out",
                 configuration: {
                   "field" => "urls",
                 }
          g.node "loop-1", "flow:loop_over_items", configuration: { "batch_size" => 2 }
          g.node "code-1",
                 "action:code",
                 configuration: {
                   "code" => "({ processed: $json.value })",
                 }
          g.node "done-1",
                 "action:set_fields",
                 name: "Done",
                 configuration: {
                   "mode" => "json",
                   "include_input" => false,
                   "json" => '{"done": true}',
                 }
          g.chain "trigger-1", "set-fields-1", "split-1", "loop-1"
          g.connect "loop-1", "code-1", output: "loop"
          g.chain "code-1", "loop-1"
          g.connect "loop-1", "done-1", output: "done"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      execution = described_class.new(workflow, "trigger-1", {}).run

      expect(execution.status).to eq("success")

      split_out_output = execution.execution_data.context_data["Split Out"]
      expect(split_out_output).to be_an(Array)
      expect(split_out_output.length).to eq(3)
      expect(split_out_output.map { |i| i["json"]["value"] }).to eq(%w[a.png b.png c.png])

      done_output = execution.execution_data.context_data["Done"]
      expect(done_output).to be_an(Array)
    end
  end
end
