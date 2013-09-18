require "spec_helper"

describe Onebox::Engine::JSON do
  let(:link) { "http://gist.github.com"}
  before do
    fake(link, response("github_gist.response"))
  end

  describe "#raw" do
    class OneboxEngineDee
      include Onebox::Engine::JSON

      def initialize(link)
        @url = link
      end
    end

    it "returns a JSON object that has a parse method" do
      object = OneboxEngineDee.new("http://gist.github.com").send(:raw)
      expect(object).to respond_to(:parse)
    end
  end
end
