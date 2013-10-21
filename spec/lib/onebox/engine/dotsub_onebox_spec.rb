require "spec_helper"

describe Onebox::Engine::DotsubOnebox do
  before(:all) do
    @link = "http://dotsub.com/view/665bd0d5-a9f4-4a07-9d9e-b31ba926ca78"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes description" do
      # og:decription tag spelled wrong in http response
      pending
      expect(html).to include("A short explanation of the micro-blogging service, Twitter.")
    end

    it "includes still" do
      expect(html).to include("/665bd0d5-a9f4-4a07-9d9e-b31ba926ca78/p")
    end

    it "includes video swf" do
      expect(html).to include("dotsub.com/media/665bd0d5-a9f4-4a07-9d9e-b31ba926ca78/m/flv/")
    end
  end
end
