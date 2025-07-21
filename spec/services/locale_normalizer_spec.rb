# frozen_string_literal: true

describe LocaleNormalizer do
  describe ".normalize_to_i18n" do
    it "matches input locales to i18n locales" do
      expect(described_class.normalize_to_i18n("en-GB")).to eq("en_GB")
      expect(described_class.normalize_to_i18n("en")).to eq("en")
      expect(described_class.normalize_to_i18n("zh")).to eq("zh_CN")
      expect(described_class.normalize_to_i18n("tr")).to eq("tr_TR")
    end

    it "converts dashes to underscores" do
      expect(described_class.normalize_to_i18n("a-b")).to eq("a_b")
    end
  end

  describe "#is_same?" do
    it "returns true for the same locale" do
      expect(described_class.is_same?("en", :en)).to be true
    end

    it "returns true for locales with different cases" do
      expect(described_class.is_same?("en", "EN")).to be true
    end

    it "returns true for locales with different separators" do
      expect(described_class.is_same?("en-US", "en_US")).to be true
    end

    it "returns false for different locales" do
      expect(described_class.is_same?("en", "ja")).to be false
    end

    it "returns true for locales with the same base language" do
      expect(described_class.is_same?("zh-CN", "zh_TW")).to be true
    end

    it "returns false for completely different locales" do
      expect(described_class.is_same?("en", "ja")).to be false
    end
  end
end
