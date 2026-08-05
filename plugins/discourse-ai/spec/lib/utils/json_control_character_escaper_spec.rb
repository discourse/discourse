# frozen_string_literal: true

RSpec.describe DiscourseAi::Utils::JsonControlCharacterEscaper do
  before { enable_current_plugin }

  describe ".escape" do
    it "escapes controls in strings while preserving formatting whitespace" do
      json = "{\n  \"message\": \"First 😊 line\nSecond line\"\n}"

      escaped = described_class.escape(json)

      expect(escaped).to eq("{\n  \"message\": \"First 😊 line\\u000aSecond line\"\n}")
    end
  end

  describe "#escape" do
    it "clears pending escape state when the next chunk contains ordinary characters" do
      chunks = ['{"a":"x' + "\\", "nyz 😊", '","b":"p', "\nq\"}"]
      escaper = described_class.new

      escaped = chunks.map { |chunk| escaper.escape(chunk) }.join

      expect(JSON.parse(escaped)).to eq("a" => "x\nyz 😊", "b" => "p\nq")
    end

    it "retains string and escape state across chunks" do
      json = "{\n  \"message\": \"A \\\"quoted\\\" value\nnext\"\n}"
      split_at = json.index('\\"')
      chunks = [json[..split_at], json[(split_at + 1)..]]
      escaper = described_class.new

      escaped = chunks.map { |chunk| escaper.escape(chunk) }.join

      expect(JSON.parse(escaped)).to eq("message" => "A \"quoted\" value\nnext")
    end

    it "handles split backslashes and a control character at the start of a chunk" do
      chunks = ['{"message":"path' + "\\", "\\", "\tend\"\n}"]
      escaper = described_class.new

      escaped = chunks.map { |chunk| escaper.escape(chunk) }.join

      expect(JSON.parse(escaped)).to eq("message" => "path\\\tend")
    end
  end
end
