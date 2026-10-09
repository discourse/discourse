# frozen_string_literal: true

describe DiscourseAi::Completions::ResponseContinuation do
  it "preserves a leading space when the model continues without repeating the prefix" do
    expect(described_class.new("quick") << " brown").to eq(" brown")
  end

  it "does not repeat an echo when the model omits outer whitespace" do
    continuation = described_class.new(" before a\n")
    expect(continuation << "before a restart.").to eq("restart.")
  end

  it "keeps HTML characters literal in the instruction" do
    expect(described_class.new("<b>cats & dogs</b>").hint).to include("<b>cats & dogs</b>")
  end

  it "removes the repeated prefix while preserving a word boundary" do
    continuation = described_class.new("before a")
    expect((continuation << "before ") + (continuation << "a restart.")).to eq(" restart.")
    expect(continuation.text).to eq(" restart.")
  end

  it "joins a word interrupted in the middle without adding a space" do
    continuation = described_class.new("restart er")
    expect(continuation << "restart erases evidence.").to eq("ases evidence.")
  end

  it "preserves Unicode and does not duplicate an unfinished repeated prefix" do
    continuation = described_class.new("猫が")
    expect(continuation << "猫").to eq("")
    expect(continuation << "が寝ています。").to eq("寝ています。")
    expect(described_class.new("word") << "wor").to eq("")
  end
end
