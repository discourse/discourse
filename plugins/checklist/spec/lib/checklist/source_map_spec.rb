# frozen_string_literal: true

RSpec.describe Checklist::SourceMap do
  describe "#checkbox_at" do
    it "resolves line ordinals against original CRLF and Unicode raw" do
      raw = "🎉 ![](<https://example.test/[x]>)[ ] visible\r\n[x] second"
      source_map = described_class.new(raw)

      first = source_map.checkbox_at(line: 0, nth: 2)
      second = source_map.checkbox_at(line: 1, nth: 0)

      expect(first.replace_in(raw, checked: true)).to start_with(
        "🎉 ![](<https://example.test/[x]>)[x] visible",
      )
      expect(second.replace_in(raw, checked: false)).to end_with("\r\n[ ] second")
    end

    it "rejects permanent and invalid source locations" do
      source_map = described_class.new("[X] permanent\n[ ] regular")

      expect(source_map.checkbox_at(line: 0, nth: 0)).to be_nil
      expect(source_map.checkbox_at(line: 10, nth: 0)).to be_nil
      expect(source_map.checkbox_at(line: 1, nth: 10)).to be_nil
    end
  end
end
