require "spec_helper"

describe Onebox::Engine::OpenGraph do
  before(:all) do
    @link = "http://flickr.com"
    fake(@link, response("flickr"))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

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
