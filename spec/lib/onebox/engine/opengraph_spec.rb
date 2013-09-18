require "spec_helper"

describe Onebox::Engine::OpenGraph do
  let(:link) { "http://flickr.com"}
  before do
    fake(link, response("flickr.response"))
  end

  describe "#raw" do
    class OneboxEngineCar
      include Onebox::Engine::OpenGraph

      def initialize(link)
        @url = link
      end
    end

    it "returns a OpenGraph object that has a metadata method" do
      object = OneboxEngineCar.new("http://flickr.com").send(:raw)
      expect(object).to respond_to(:metadata)
    end
  end
end
