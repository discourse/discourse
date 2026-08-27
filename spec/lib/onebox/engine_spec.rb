# frozen_string_literal: true

RSpec.describe Onebox::Engine do
  class OneboxEngineExample
    include Onebox::Engine

    def to_html
      "Hello #{link}"
    end

    def data
      { foo: raw[:key], url: @url }
    end

    def raw
      { key: "value" }
    end
  end

  describe "#link" do
    before { Onebox::View.stubs(:template).returns("this should be a template") }

    it "escapes `link`" do
      html = OneboxEngineExample.new("http://foo.com/bar?a='&b=2").to_html
      expect(html).not_to match(/'/)
    end
  end

  describe ".placeholder_html" do
    let(:onebox) { OneboxEngineExample.new("http://eviltrout.com") }

    it "returns `to_html` by default" do
      expect(onebox.to_html).to eq(onebox.placeholder_html)
    end
  end

  describe ".===" do
    class OneboxEngineTripleEqual
      include Onebox::Engine
      @@matcher = /example/
    end

    it "returns true if argument matches the matcher" do
      result = OneboxEngineTripleEqual === URI("http://www.example.com/product/5?var=foo&bar=5")
      expect(result).to eq(true)
    end
  end

  describe "origins_to_regexes" do
    it "converts host-only URLs to regexes with URL boundaries" do
      result = Onebox::Engine.origins_to_regexes(%w[https://example.com https://example2.com])
      expect(result).to eq(
        [
          %r{\Ahttps://example\.com(?::\d+(?:[/?#]|\z)|[/?#]|\z)}i,
          %r{\Ahttps://example2\.com(?::\d+(?:[/?#]|\z)|[/?#]|\z)}i,
        ],
      )
    end

    it "matches host-only URLs only at URL boundaries" do
      regex = Onebox::Engine.origins_to_regexes(["https://example.com"]).first

      %w[
        https://example.com
        https://example.com/embed
        https://example.com?foo=bar
        https://example.com#fragment
        https://example.com:3000/embed
      ].each { |url| expect(url).to match(regex) }

      %w[
        https://example.com.attacker.example/embed
        https://example.com:3000.attacker.example/embed
      ].each { |url| expect(url).not_to match(regex) }
    end

    it "limits wildcard origins to a single URL authority" do
      regex = Onebox::Engine.origins_to_regexes(["https://*.example.com"]).first

      %w[https://embed.example.com/player https://deep.embed.example.com/player].each do |url|
        expect(url).to match(regex)
      end

      %w[
        https://attacker.example/path.example.com/player
        https://attacker.example?.example.com/
        https://attacker.example#.example.com/
        https://attacker.example\\@embed.example.com/player
        https://embed.example.com.attacker.example/player
      ].each { |url| expect(url).not_to match(regex) }
    end

    it "treats '*' as a catch-all" do
      result = Onebox::Engine.origins_to_regexes(%w[https://example.com * https://example2.com])
      expect(result).to eq([/.*/])
    end
  end

  describe "handles_content_type?" do
    class OneboxEngineImages
      include Onebox::Engine
      @@matcher_content_type = %r{^image/png$}
    end

    it "returns true if argument matches the matcher" do
      result = OneboxEngineImages.handles_content_type?("image/png")
      expect(result).to eq(true)
    end
  end

  class AlwaysHttpsEngineExample < OneboxEngineExample
    always_https
  end

  describe "always_https" do
    it "never returns a plain http url" do
      url = "http://play.google.com/store/apps/details?id=com.google.android.inputmethod.latin"
      onebox = AlwaysHttpsEngineExample.new(url)
      result = onebox.to_html
      expect(result).to_not match(/http(?!s)/)
      expect(result).to_not match(%r{['"]//})
      expect(result).to match(/https/)
    end
  end

  describe ".onebox_name" do
    module ScopeForTemplateName
      class TemplateNameOnebox
        include Onebox::Engine
      end
    end

    let(:onebox_name) { ScopeForTemplateName::TemplateNameOnebox.onebox_name }

    it "should not include the scope" do
      expect(onebox_name).not_to include("ScopeForTemplateName", "scopefortemplatename")
    end

    it "should not include the word Onebox" do
      expect(onebox_name).not_to include("onebox", "Onebox")
    end
  end
end
