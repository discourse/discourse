# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::ToolArgumentsParser do
  before { enable_current_plugin }

  it "returns hash arguments with symbolized keys" do
    expect(described_class.parse("kind" => "group", "options" => { "notify" => true })).to eq(
      { kind: "group", options: { notify: true } },
    )
  end

  it "parses blank arguments as an empty hash" do
    expect(described_class.parse("  ")).to eq({})
  end

  it "parses arguments with padding" do
    expect(described_class.parse(" {\"kind\":\"group\",\"query\":\"friend\"} ")).to eq(
      { kind: "group", query: "friend" },
    )
  end

  it "repairs an omitted opening delimiter" do
    expect(described_class.parse("kind\": \"group\", \"query\": \"friend\"} ")).to eq(
      { kind: "group", query: "friend" },
    )
  end

  it "repairs omitted closing delimiters" do
    expect(described_class.parse('{"outer":{"inner":"value"')).to eq({ outer: { inner: "value" } })
  end

  it "raises on invalid arguments" do
    expect { described_class.parse("not-json") }.to raise_error(JSON::ParserError)
  end
end
