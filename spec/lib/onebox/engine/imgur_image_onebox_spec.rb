require "spec_helper"

describe Onebox::Engine::ImgurImageOnebox do
  before(:all) do
    @link = "http://imgur.com/gallery/twoDTCU"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes image" do
      expect(html).to include("twoDTCU.jpg")
    end
  end
end
