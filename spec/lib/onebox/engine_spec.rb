require "spec_helper"

class Onebox::Engine::Foo
  include Onebox::Engine
  @@matcher = /example/
end

describe Onebox::Engine do
  describe "#to_html" do
    it "returns formatted html"
  end

  describe "#===" do
    it "returns true if argument matches the matcher" do
      onebox = Onebox::Engine::Foo
      result = onebox.===("http://www.example.com/product/5?var=foo&bar=5")
      expect(result).to eq(true)
    end
  end
end
