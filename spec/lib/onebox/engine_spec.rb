require "spec_helper"

class OneboxEngineExample
  include Onebox::Engine

  def data
    { foo: raw[:key], url: @url }
  end

  def raw
    { key: "value" }
  end

  def view
    @view.tap do |layout|
      layout.view.template = %|<div class="onebox"><a href="{{url}}"></a></div>|
    end
  end
end

describe Onebox::Engine do
  describe "#to_html" do
    it "returns the onebox wrapper" do
      html = OneboxEngineExample.new("foo").to_html
      expect(html).to include(%|class="onebox"|)
    end

    it "doesn't allow XSS injection" do
      html = OneboxEngineExample.new(%|http://foo.com" onscript="alert('foo')|).to_html
      expect(html).not_to include(%|onscript="alert('foo')|)
    end
  end

  describe "#record" do
    class OneboxEngineRecord
      include Onebox::Engine

      def data
        "new content"
      end
    end

    it "returns cached value for given url if its url is already in cache" do
      cache = { "http://example.com" => "old content" }
      result = OneboxEngineRecord.new("http://example.com", cache).send(:record)
      expect(result).to eq("old content")
    end

    it "stores cache value for given url if cache key doesn't exist" do
      cache = { "http://example.com1" => "old content" }
      result = OneboxEngineRecord.new("http://example.com", cache).send(:record)
      expect(result).to eq("new content")
    end
  end

  describe ".===" do
    class OneboxEngineTripleEqual
      include Onebox::Engine
      @@matcher = /example/
    end
    it "returns true if argument matches the matcher" do
      result = OneboxEngineTripleEqual === "http://www.example.com/product/5?var=foo&bar=5"
      expect(result).to eq(true)
    end
  end

  describe ".matches" do
    class OneboxEngineMatches
      include Onebox::Engine

      matches do
        find "foo.com"
      end
    end

    it "sets @@matcher to a regular expression" do
      regex = OneboxEngineMatches.class_variable_get(:@@matcher)
      expect(regex).to be_a(Regexp)
    end
  end

  describe ".template_name" do
    module ScopeForTemplateName
      class TemplateNameOnebox
        include Onebox::Engine
      end
    end

    let(:template_name) { ScopeForTemplateName::TemplateNameOnebox.template_name }

    it "should not include the scope" do
      expect(template_name).not_to include("ScopeForTemplateName", "scopefortemplatename")
    end

    it "should not include the word Onebox" do
      expect(template_name).not_to include("onebox", "Onebox")
    end
  end
end
