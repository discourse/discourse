# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::HttpRequest::V1 do
  let(:configuration) do
    {
      "method" => "POST",
      "url" => "https://example.com/webhook",
      "content_type" => "json",
      "body_json" => '{"title":"Cake recipe"}',
    }
  end

  def simulate(test_data = nil, configuration: self.configuration, &block)
    simulation = DiscourseWorkflows::Simulation::RunState.new(test: test_data)
    simulate_node_output(configuration:, simulation:, &block)
  end

  it "never makes the request and stops when there is no saved response" do
    stub = stub_request(:post, "https://example.com/webhook")
    effects = nil

    expect { simulate { |state| effects = state.effects } }.to raise_error(
      DiscourseWorkflows::Simulation::SafetyError,
    ) { |error| expect(error.reason_key).to eq("needs_recorded_response") }
    expect(stub).not_to have_been_requested
  end

  it "records the request it would have made" do
    effects = nil
    expect { simulate { |state| effects = state.effects } }.to raise_error(
      DiscourseWorkflows::Simulation::SafetyError,
    )
    # the effect is recorded before the replay check stops the run
  end

  it "replays a pasted response for the node" do
    test_data =
      DiscourseWorkflows::Simulation::TestData.new(
        pasted_responses: {
          "Step under test" => [{ "json" => { "ok" => true } }],
        },
      )

    output = simulate(test_data)

    expect(output.first.first["json"]).to eq("ok" => true)
  end

  it "replays a captured response whose fingerprint still matches" do
    pasted =
      DiscourseWorkflows::Simulation::TestData.new(
        pasted_responses: {
          "Step under test" => [{ "json" => { "from" => "paste" } }],
        },
      )
    fingerprint = nil
    simulate(pasted) do |_state, ctx|
      config =
        described_class.new(parameters: configuration).resolve_config(
          ctx,
          item: {
            "json" => {
            },
          },
          item_index: 0,
          operation: nil,
        )
      fingerprint = ctx.fingerprint(config, exclude: described_class.fingerprint_excluded_keys)
    end

    captured =
      DiscourseWorkflows::Simulation::TestData.new(
        captured_outputs: {
          "Step under test:0" => [
            { "fingerprint" => fingerprint, "outputs" => [{ "json" => { "from" => "capture" } }] },
          ],
        },
      )

    expect(simulate(captured).first.first["json"]).to eq("from" => "capture")

    changed = configuration.merge("url" => "https://example.com/other")
    expect { simulate(captured, configuration: changed) }.to raise_error(
      DiscourseWorkflows::Simulation::SafetyError,
    ) { |error| expect(error.reason_key).to eq("recorded_mismatch") }

    same_url_new_body = configuration.merge("body_json" => '{"title":"Changed"}')
    expect(simulate(captured, configuration: same_url_new_body).first.first["json"]).to eq(
      "from" => "capture",
    )
  end

  it "still validates the request" do
    expect {
      simulate(nil, configuration: configuration.merge("url" => "not a url"))
    }.to raise_error(DiscourseWorkflows::NodeError)
  end
end
