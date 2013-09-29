require "spec_helper"

describe Onebox::Engine::StackExchangeOnebox do
  before(:all) do
    @link = "http://stackoverflow.com/questions/17992553/concept-behind-these-four-lines-of-tricky-c-code"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns the question title" do
      expect(html).to include("Concept behind these 4 lines of tricky C++ code")
    end

    it "returns the question" do
      expect(html).to include("Why does this code gives output C++Sucks? Can anyone explain the concept behind it?")
    end

    it "returns the question URL" do
      expect(html).to include(link)
    end
  end
end

