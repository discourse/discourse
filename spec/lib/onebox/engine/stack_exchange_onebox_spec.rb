require "spec_helper"

describe Onebox::Engine::StackExchangeOnebox do
  before(:all) do
    @link = "http://stackoverflow.com/questions/17992553/concept-behind-these-four-lines-of-tricky-c-code"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    it "has the question" do
      expect(html).to include("Why does this code gives output C++Sucks? Can anyone explain the concept behind it?")
    end
  end
end

