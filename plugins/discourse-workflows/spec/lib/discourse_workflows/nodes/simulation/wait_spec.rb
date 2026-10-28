# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Wait::V1 do
  it "records a delay and passes the items through" do
    configuration = { "resume" => "time_interval", "wait_amount" => 2, "wait_unit" => "hours" }
    effects = nil

    output =
      simulate_node_output(configuration:, input_items: [{ "json" => { "a" => 1 } }]) do |state|
        effects = state.effects
      end

    expect(effects).to contain_exactly(
      a_hash_including("type" => "delay", "fields" => { "seconds" => 2.hours.to_i }),
    )
    expect(output.first.first["json"]).to eq("a" => 1)
  end

  it "blocks a webhook wait" do
    configuration = { "resume" => "webhook" }

    expect { simulate_node_output(configuration:) }.to raise_error(
      DiscourseWorkflows::Simulation::SafetyError,
    ) { |error| expect(error.reason_key).to eq("webhook_wait") }
  end
end
