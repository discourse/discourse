require "spec_helper"

describe Onebox::Engine::StackExchangeOnebox do
  before(:all) do
    @link = "http://stackoverflow.com/questions/17992553/concept-behind-these-four-lines-of-tricky-c-code"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes question" do
      expect(html).to include("Why does this code gives output C++Sucks? Can anyone explain the concept behind it?")
    end
  end
end

