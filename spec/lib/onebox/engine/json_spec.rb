require "spec_helper"

describe Onebox::Engine::JSON do
  before(:all) do
    @link = "http://gist.github.com"
    fake(@link, response("githubgist"))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  describe "#raw" do
<<<<<<< HEAD
    class OneboxEngineJson
=======
    class OneboxEngineJSON
      include Onebox::Engine
>>>>>>> We need the behavior of engine, renaming classes for clarity.
      include Onebox::Engine::JSON

      def initialize(link)
        @url = link
      end
    end

    it "returns a hash" do
<<<<<<< HEAD
      object = OneboxEngineJson.new("http://gist.github.com").send(:raw)
=======
      object = OneboxEngineJSON.new("http://gist.github.com").send(:raw)
>>>>>>> We need the behavior of engine, renaming classes for clarity.
      expect(object).to be_a(Hash)
    end
  end
end
