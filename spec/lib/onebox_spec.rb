require "spec_helper"

describe Onebox do
  describe ".preview" do
    it "creates a cache that responds as expected" do
      url = "http://www.example.com"
      preview = Onebox.preview(url)
      cache = preview.cache
      expect(cache).to respond_to(:key?, :store, :fetch)
    end

    it "stores the value in cache if it doesn't exist" do
      url = "http://www.example.com"
      preview = Onebox.preview(url)
      preview.to_s
      cache = preview.cache
      expect(cache.key?(url)).to eq(true)
    end

    it "replaces the cache if the cache is expired" do
      url = "http://www.example.com"
      preview = Onebox.preview(url, cache: Moneta.new(:Memory, expires: 100000, serializer: :json))
      cache = preview.cache
      expect(cache.fetch(url)).to be(nil)
    end
  end

  describe "templates" do
    let(:templates) { Dir["templates/*.mustache"] - ["templates/_layout.mustache"] }

    def expect_templates_to_not_match(text)
      templates.each do |template|
        expect(File.read(template)).not_to match(text)
      end
    end

    it "should not contain any triple braces" do
      expect_templates_to_not_match(/\{\{\{/)
    end

    it "should not contain any script tags" do
      expect_templates_to_not_match(/<script/)
    end

    it "should not contain any on*" do
      expect_templates_to_not_match(/\s*on.+\s*=/)
    end
  end
end
