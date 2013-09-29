require "spec_helper"

describe Onebox::Engine::JSON do
  before(:all) do
    @link = "http://gist.github.com"
    fake(@link, response("githubgist"))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  describe "#raw" do
    class OneboxEngineJson
      include Onebox::Engine::JSON

      def initialize(link)
        @url = link
      end
    end

    it "returns a hash" do
      object = OneboxEngineJson.new("http://gist.github.com").send(:raw)
      expect(object).to be_a(Hash)
    end
  end
end
