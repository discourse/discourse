# frozen_string_literal: true

RSpec.describe Checklist::Checkbox do
  describe "#checked?" do
    it "is true for a checked segment" do
      expect(described_class.new(offset: 0, segment: "[x]", permanent: false)).to be_checked
    end

    it "is false for unchecked and legacy empty segments" do
      expect(described_class.new(offset: 0, segment: "[ ]", permanent: false)).not_to be_checked
      expect(described_class.new(offset: 0, segment: "[]", permanent: false)).not_to be_checked
    end
  end

  describe "#permanent?" do
    it "reflects the permanent flag" do
      expect(described_class.new(offset: nil, segment: nil, permanent: true)).to be_permanent
      expect(described_class.new(offset: 0, segment: "[x]", permanent: false)).not_to be_permanent
    end
  end

  describe "#toggleable?" do
    it "is true for a located, non-permanent checkbox" do
      expect(described_class.new(offset: 0, segment: "[ ]", permanent: false)).to be_toggleable
    end

    it "is false for a permanent checkbox" do
      expect(described_class.new(offset: nil, segment: nil, permanent: true)).not_to be_toggleable
    end

    it "is false for a checkbox that could not be located" do
      expect(described_class.new(offset: nil, segment: nil, permanent: false)).not_to be_toggleable
    end
  end

  describe "#replace_in" do
    it "checks an unchecked checkbox" do
      checkbox = described_class.new(offset: 2, segment: "[ ]", permanent: false)

      expect(checkbox.replace_in("- [ ] first", checked: true)).to eq("- [x] first")
    end

    it "unchecks a checked checkbox" do
      checkbox = described_class.new(offset: 0, segment: "[x]", permanent: false)

      expect(checkbox.replace_in("[x] done", checked: false)).to eq("[ ] done")
    end

    it "expands a legacy empty checkbox when checking it" do
      checkbox = described_class.new(offset: 0, segment: "[]", permanent: false)

      expect(checkbox.replace_in("[] first", checked: true)).to eq("[x] first")
    end

    it "handles multibyte characters before the checkbox" do
      checkbox = described_class.new(offset: 9, segment: "[ ]", permanent: false)

      expect(checkbox.replace_in("🎉 party\n\n[ ] task", checked: true)).to eq("🎉 party\n\n[x] task")
    end
  end
end
