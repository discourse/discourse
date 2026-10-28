# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowTestSourceCaptures do
  let(:nodes) do
    [
      { "name" => "Call API", "type" => "action:http_request", "typeVersion" => "1.0" },
      { "name" => "Log it", "type" => "action:log", "typeVersion" => "1.0" },
    ]
  end

  def run(items, status: "success", truncated: false, run_index: 0, input_count: 2)
    {
      "run_index" => run_index,
      "status" => status,
      "inputs" => [{ "index" => 0, "items" => [], "item_count" => input_count }],
      "outputs" => [
        { "index" => 0, "items" => items, "item_count" => items.size, "truncated" => truncated },
      ],
    }
  end

  it "groups a recorded node's outputs by paired input item and ignores other nodes" do
    run_data = {
      "Call API" => [
        run(
          [
            { "json" => { "a" => 1 }, "pairedItem" => { "item" => 1 } },
            { "json" => { "b" => 2 }, "pairedItem" => { "item" => 0 } },
            { "json" => { "c" => 3 }, "pairedItem" => { "item" => 1 } },
          ],
        ),
      ],
      "Log it" => [run([{ "json" => {} }])],
    }

    captured = described_class.from_run_data(run_data, nodes:)

    expect(captured.keys).to eq(["Call API:0"])
    expect(captured["Call API:0"]).to eq(
      [
        { "fingerprint" => nil, "outputs" => [{ "json" => { "b" => 2 } }] },
        {
          "fingerprint" => nil,
          "outputs" => [{ "json" => { "a" => 1 } }, { "json" => { "c" => 3 } }],
        },
      ],
    )
  end

  it "skips failed, truncated and unpairable runs" do
    run_data = {
      "Call API" => [
        run([{ "json" => {} }], status: "error"),
        run([{ "json" => { "big" => { "__truncated" => true } } }], run_index: 1, input_count: 1),
        run([{ "json" => {} }], truncated: true, run_index: 2),
        run([{ "json" => {} }], run_index: 3),
      ],
    }

    expect(described_class.from_run_data(run_data, nodes:)).to eq({})
  end
end
