require "spec_helper"

describe Onebox::Engine::HTML do
  before(:all) do
    @link = "http://amazon.com"
    fake(@link, response("amazon"))
  end
  before(:each) { Onebox.options.cache.clear }

  describe "#raw" do
    class OneboxEngineHTML
      include Onebox::Engine
      include Onebox::Engine::HTML

      def initialize(link)
        @url = link
      end
    end

    it "returns a Nokogiri object that has a css method" do
      object = OneboxEngineHTML.new("http://amazon.com").send(:raw)
      expect(object).to respond_to(:css)
    end
  end
end
