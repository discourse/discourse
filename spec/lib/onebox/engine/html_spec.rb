require "spec_helper"

describe Onebox::Engine::HTML do
  before(:all) do
    @link = "http://example.com"
    fake(@link, response("example"))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

  describe "#raw" do
    class OneboxEngineHTML
      include Onebox::Engine
      include Onebox::Engine::HTML

      def initialize(link)
        @url = link
      end
    end

    it "returns a Nokogiri object that has a css method" do
      object = OneboxEngineHTML.new("http://example.com").send(:raw)
      expect(object).to respond_to(:css)
    end
  end
end
