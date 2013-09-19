require "spec_helper"

describe Onebox::Engine::HTML do
  let(:link) { "http://example.com"}
  before do
    fake(link, response("example"))
  end

  describe "#raw" do
    class OneboxEngineFoo
      include Onebox::Engine::HTML

      def initialize(link)
        @url = link
      end
    end

    it "returns a Nokogiri object that has a css method" do
      object = OneboxEngineFoo.new("http://example.com").send(:raw)
      expect(object).to respond_to(:css)
    end
  end
end
