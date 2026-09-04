# frozen_string_literal: true

RSpec.describe BrowserPageviewEventLanguageNormalizer do
  describe ".normalize" do
    it "keeps the primary language and optional script in canonical form" do
      languages = [nil, "", "_", "EN_us", "es-MX", "zh-Hant-TW", "zh-cmn-Hans-CN", "sr-Cyrl-RS"]

      expect(languages.index_with { |language| described_class.normalize(language) }).to eq(
        nil => nil,
        "" => "",
        "_" => "",
        "EN_us" => "en",
        "es-MX" => "es",
        "zh-Hant-TW" => "zh-Hant",
        "zh-cmn-Hans-CN" => "zh-Hans",
        "sr-Cyrl-RS" => "sr-Cyrl",
      )
    end
  end
end
