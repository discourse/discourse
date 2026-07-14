# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::CodeRunner do
  let(:runtime_state) { DiscourseWorkflows::Executor::NodeExecutionContext::RuntimeState.new }

  def build_runner(items: [{ "json" => {} }], parameters: {}, resolver_context: {})
    described_class.new(
      input_items: items,
      parameters: parameters,
      input_context: {
      },
      resolver_context: resolver_context,
      user: nil,
      vars: nil,
      flow_context: {
      },
      runtime_state: runtime_state,
    )
  end

  it "runs JavaScript in runCode mode" do
    result =
      build_runner.run({ "nodeMode" => "runCode", "code" => "return { json: { value: 2 } };" }, 0)

    expect(result).to eq("json" => { "value" => 2 })
  end

  it "runs JavaScript once for all items with $input helpers" do
    items = [{ "json" => { "value" => 1 } }, { "json" => { "value" => 2 } }]
    result =
      build_runner(items: items).run(
        {
          "nodeMode" => "runOnceForAllItems",
          "code" => "return $input.all().map(function(item) { return item.json.value; });",
        },
        0,
      )

    expect(result).to eq([1, 2])
  end

  it "runs JavaScript once for each item in the requested chunk" do
    items = [{ "json" => { "value" => 1 } }, { "json" => { "value" => 2 } }]
    result =
      build_runner(items: items).run(
        {
          "nodeMode" => "runOnceForEachItem",
          "code" => "return { json: { value: $json.value, index: $itemIndex } };",
          "chunk" => {
            "startIndex" => 1,
            "count" => 1,
          },
        },
        0,
      )

    expect(result).to eq([{ "json" => { "value" => 2, "index" => 1 } }])
  end

  it "merges sandbox logs into the runtime state" do
    build_runner.run(
      { "nodeMode" => "runCode", "code" => 'console.log("from code"); return null;' },
      0,
    )

    expect(runtime_state.log.entries).to contain_exactly(
      include("level" => "info", "message" => "from code"),
    )
  end

  it "rejects invalid JavaScript additional property names" do
    expect {
      build_runner.run(
        {
          "nodeMode" => "runCode",
          "code" => "return null;",
          "additionalProperties" => {
            "not valid" => true,
          },
        },
        0,
      )
    }.to raise_error(ArgumentError, "Invalid JavaScript property name: not valid")
  end

  it "preserves JavaScript null and undefined as distinct Ruby values" do
    runner = build_runner

    null_result = runner.run({ "nodeMode" => "runCode", "code" => "return null;" }, 0)
    undefined_result = runner.run({ "nodeMode" => "runCode", "code" => "return;" }, 0)

    expect(null_result).to be_nil
    expect(undefined_result).to eq(described_class::JAVASCRIPT_UNDEFINED)
  end
end
