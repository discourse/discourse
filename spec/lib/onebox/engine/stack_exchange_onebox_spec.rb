require "spec_helper"

describe Onebox::Engine::StackExchangeOnebox do
  before(:all) do
    @link = "http://stackoverflow.com/questions/17992553/concept-behind-these-four-lines-of-tricky-c-code"
    fake("https://api.stackexchange.com/2.1/questions/17992553?site=stackoverflow.com", response(described_class.onebox_name))
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes question" do
      expect(html).to include("Concept behind these four lines of tricky C++ code")
    end
  end
end
