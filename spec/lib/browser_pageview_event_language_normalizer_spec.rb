# frozen_string_literal: true

RSpec.describe BrowserPageviewEventLanguageNormalizer do
  describe ".normalize" do
    it "returns nil when no language was recorded" do
      expect(described_class.normalize(nil)).to be_nil
    end

    it "keeps an empty recorded language empty" do
      expect(described_class.normalize("")).to eq("")
    end

    it "removes the region from Spanish" do
      expect(described_class.normalize("es-MX")).to eq("es")
    end

    it "canonicalizes casing and underscore separators" do
      expect(described_class.normalize("EN_us")).to eq("en")
    end

    it "preserves the Traditional Chinese script" do
      expect(described_class.normalize("zh-Hant-TW")).to eq("zh-Hant")
    end

    it "preserves the Simplified Chinese script and removes an extlang" do
      expect(described_class.normalize("zh-cmn-Hans-CN")).to eq("zh-Hans")
    end

    it "preserves the Serbian Cyrillic script" do
      expect(described_class.normalize("sr-Cyrl-RS")).to eq("sr-Cyrl")
    end

    it "preserves the Serbian Latin script" do
      expect(described_class.normalize("sr-Latn-RS")).to eq("sr-Latn")
    end

    it "preserves the Punjabi Gurmukhi script" do
      expect(described_class.normalize("pa-Guru-IN")).to eq("pa-Guru")
    end

    it "preserves the Punjabi Arabic script" do
      expect(described_class.normalize("pa-Arab-PK")).to eq("pa-Arab")
    end

    it "removes variants from Slovenian" do
      expect(described_class.normalize("sl-rozaj-biske-1994")).to eq("sl")
    end

    it "removes Unicode extensions from English" do
      expect(described_class.normalize("en-US-u-hc-h12")).to eq("en")
    end
  end
end
