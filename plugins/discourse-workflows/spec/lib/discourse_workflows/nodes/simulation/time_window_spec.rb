# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TimeWindow::V1 do
  it "evaluates the window against the pinned instant" do
    pinned = Time.zone.parse("2026-01-07 03:00:00 UTC")
    simulation = DiscourseWorkflows::Simulation::RunState.new(now: pinned)
    configuration = {
      "timezone" => "UTC",
      "use_time_range" => true,
      "start_time" => "09:00",
      "end_time" => "17:00",
    }

    output = simulate_node_output(configuration:, simulation:)

    expect(output.first).to eq([])
    expect(output.last.first["json"]).to eq({})
  end
end
