# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::StepLog do
  subject(:log) { described_class.new }

  it "reports warnings separately from errors" do
    log.info("nothing to see")
    expect(log.warnings?).to eq(false)

    log.warn("something was dropped")

    expect(log.warnings?).to eq(true)
    expect(log.errors?).to eq(false)
  end

  it "keeps warnings when merging" do
    other = described_class.new
    other.warn("dropped")

    log.merge(other)

    expect(log.warnings?).to eq(true)
  end
end

RSpec.describe DiscourseWorkflows::Executor::Step do
  subject(:step) do
    described_class.new(
      node_id: "n",
      node_name: "N",
      node_type: "action:log",
      position: 0,
      input: [],
    )
  end

  it "stays a success when it warned, and says so" do
    step.warned = true
    step.succeed!(output: [])

    expect(step.status).to eq(described_class::SUCCESS)
    expect(step.success?).to eq(true)
    expect(step.warned?).to eq(true)
    expect(step.to_h["warned"]).to eq(true)
  end

  it "does not claim a warning otherwise" do
    step.succeed!(output: [])

    expect(step.warned?).to eq(false)
    expect(step.to_h).not_to have_key("warned")
  end
end

RSpec.describe DiscourseWorkflows::ExecutionSerializer do
  fab!(:workflow, :discourse_workflows_workflow)

  it "exposes the warned flag on the execution and on every step that carries it" do
    execution =
      Fabricate(:discourse_workflows_execution, workflow: workflow, status: :success, warned: true)
    Fabricate(
      :discourse_workflows_execution_data,
      execution: execution,
      data: {
        "entries" => {
          "A" => [
            {
              "node_id" => "a",
              "node_name" => "A",
              "node_type" => "action:log",
              "position" => 0,
              "status" => "success",
              "warned" => true,
            },
          ],
        },
      },
    )

    json = described_class.new(execution.reload, root: false).as_json

    expect(json[:warned]).to eq(true)
    expect(json[:steps].first[:warned]).to eq(true)
  end
end
