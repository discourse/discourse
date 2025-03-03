# frozen_string_literal: true

describe HttpLanguageParser do
  it "returns the default locale when no language is matched" do
    expect(HttpLanguageParser.parse("")).to eq(SiteSetting.default_locale)
  end

  it "returns the matched locale when a language is matched" do
    expect(HttpLanguageParser.parse("en")).to eq("en")
  end

  it "returns the matched locale when a language and region are matched" do
    expect(HttpLanguageParser.parse("en-US")).to eq("en")
  end

  it "returns the matched locale regardless of dash or underscore usage" do
    expect(HttpLanguageParser.parse("zh-CN")).to eq("zh_CN")
    expect(HttpLanguageParser.parse("zh_CN")).to eq("zh_CN")
  end
end
