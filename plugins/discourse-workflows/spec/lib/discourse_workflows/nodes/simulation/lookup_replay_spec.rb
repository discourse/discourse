# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Group::V1 do
  fab!(:user)
  fab!(:admin)
  fab!(:group)

  let(:configuration) do
    {
      "operation" => "check_membership",
      "username" => user.username,
      "group_id" => group.id,
      "actor_username" => admin.username,
    }
  end

  it "captures a live lookup when the run is capturing" do
    group.add(user)
    captures = nil
    test_data = DiscourseWorkflows::Simulation::TestData.new(capture: true)

    simulate_node_output(
      configuration:,
      simulation: DiscourseWorkflows::Simulation::RunState.new(test: test_data),
    ) { |state| captures = state.captures }

    entry = captures.fetch("Step under test:0").first
    expect(entry["fingerprint"]).to be_present
    expect(entry["outputs"].first["json"]["group_membership"]).to include("in_group" => true)
  end

  it "replays a captured lookup instead of reading the live site" do
    captures = nil
    capturing = DiscourseWorkflows::Simulation::TestData.new(capture: true)
    simulate_node_output(
      configuration:,
      simulation: DiscourseWorkflows::Simulation::RunState.new(test: capturing),
    ) { |state| captures = state.captures }

    group.add(user)
    replaying = DiscourseWorkflows::Simulation::TestData.new(captured_outputs: captures)
    output =
      simulate_node_output(
        configuration:,
        simulation: DiscourseWorkflows::Simulation::RunState.new(test: replaying),
      )

    expect(output.first.first["json"]["group_membership"]).to include("in_group" => false)
  end

  it "stops when the lookup no longer matches its capture" do
    captures = nil
    capturing = DiscourseWorkflows::Simulation::TestData.new(capture: true)
    simulate_node_output(
      configuration:,
      simulation: DiscourseWorkflows::Simulation::RunState.new(test: capturing),
    ) { |state| captures = state.captures }

    other = Fabricate(:group)
    replaying = DiscourseWorkflows::Simulation::TestData.new(captured_outputs: captures)

    expect {
      simulate_node_output(
        configuration: configuration.merge("group_id" => other.id),
        simulation: DiscourseWorkflows::Simulation::RunState.new(test: replaying),
      )
    }.to raise_error(DiscourseWorkflows::Simulation::SafetyError) { |error|
      expect(error.reason_key).to eq("lookup_mismatch")
    }
  end
end
