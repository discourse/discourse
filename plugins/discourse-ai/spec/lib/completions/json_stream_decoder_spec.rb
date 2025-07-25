# frozen_string_literal: true

describe DiscourseAi::Completions::JsonStreamDecoder do
  let(:decoder) { DiscourseAi::Completions::JsonStreamDecoder.new }

  before { enable_current_plugin }

  it "should be able to parse simple messages" do
    result = decoder << "data: #{{ hello: "world" }.to_json}"
    expect(result).to eq([{ hello: "world" }])
  end

  it "should handle anthropic mixed stlye streams" do
    stream = (<<~TEXT).split("|")
      event: |message_start|
      data: |{"hel|lo": "world"}|

      event: |message_start
      data: {"foo": "bar"}

      event: |message_start
      data: {"ba|z": "qux"|}

      [DONE]
    TEXT

    results = []
    stream.each { |chunk| results << (decoder << chunk) }

    expect(results.flatten.compact).to eq([{ hello: "world" }, { foo: "bar" }, { baz: "qux" }])
  end

  it "should be able to handle complex overlaps" do
    stream = (<<~TEXT).split("|")
      data: |{"hel|lo": "world"}

      data: {"foo": "bar"}

      data: {"ba|z": "qux"|}

      [DONE]
    TEXT

    results = []
    stream.each { |chunk| results << (decoder << chunk) }

    expect(results.flatten.compact).to eq([{ hello: "world" }, { foo: "bar" }, { baz: "qux" }])
  end
end
