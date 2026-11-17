# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::GeneratedOutput do
  it "counts assembled reasoning and tool arguments once rather than cumulative partials or signatures" do
    tokenizer = DiscourseAi::Tokenizer::OpenAiTokenizer
    output = described_class.new
    output << "Answer"
    output << DiscourseAi::Completions::Thinking.new(message: "Consider ", partial: true)
    output << DiscourseAi::Completions::Thinking.new(message: "evidence", partial: true)
    output << DiscourseAi::Completions::Thinking.new(
      message: "Consider evidence",
      provider_info: {
        encrypted: "opaque" * 100,
      },
    )
    call =
      DiscourseAi::Completions::ToolCall.new(id: "read", name: "read", parameters: { query: "ev" })
    call.partial = true
    output << call
    call.parameters = { query: "evidence" }
    call.partial = false
    output << call
    expect(output.size(tokenizer)).to eq(
      tokenizer.size("Answer") + tokenizer.size("Consider evidence") +
        tokenizer.size({ name: "read", arguments: { query: "evidence" } }.to_json),
    )
  end

  it "retains pending cancelled reasoning and successive completed reasoning blocks" do
    tokenizer = DiscourseAi::Tokenizer::OpenAiTokenizer
    output = described_class.new
    output << DiscourseAi::Completions::Thinking.new(message: "First ", partial: true)
    output << DiscourseAi::Completions::Thinking.new(message: "block", partial: true)
    output << DiscourseAi::Completions::Thinking.new(message: "First block")
    output << DiscourseAi::Completions::Thinking.new(message: "Second block")
    output << DiscourseAi::Completions::Thinking.new(message: "Cancelled pending", partial: true)
    expect(output.size(tokenizer)).to eq(tokenizer.size("First blockSecond blockCancelled pending"))
  end

  it "assembles interleaved tool IDs independently and snapshots mutable parameters" do
    tokenizer = DiscourseAi::Tokenizer::OpenAiTokenizer
    output = described_class.new
    first =
      DiscourseAi::Completions::ToolCall.new(id: "one", name: "read", parameters: { query: "a" })
    second =
      DiscourseAi::Completions::ToolCall.new(id: "two", name: "read", parameters: { query: "b" })
    first.partial = second.partial = true
    output << first << second
    first.parameters = { query: "alpha" }
    first.partial = false
    output << first
    second.parameters = { query: "beta pending" }
    output << second
    second.parameters[:query] = "not admitted"
    expect(output.size(tokenizer)).to eq(
      tokenizer.size({ name: "read", arguments: { query: "alpha" } }.to_json) +
        tokenizer.size({ name: "read", arguments: { query: "beta pending" } }.to_json),
    )
  end

  it "replaces cumulative structured snapshots instead of appending their prefixes" do
    tokenizer = DiscourseAi::Tokenizer::OpenAiTokenizer
    output = described_class.new
    structured = DiscourseAi::Completions::StructuredOutput.new(answer: { type: "string" })
    structured << '{"answer":"Par'
    output << structured
    structured << 'tial"}'
    output << structured
    structured.finish
    output << structured
    expect(output.size(tokenizer)).to eq(tokenizer.size('{"answer":"Partial"}'))
  end
end
