# frozen_string_literal: true

RSpec.describe Onebox::Engine::JSON do
  let(:link) { "http://stackoverflow.com" }

  before do
    stub_request(:get, link).to_return(status: 200, body: onebox_response("stackexchange-question"))
  end

  describe "#raw" do
    class OneboxEngineJSON
      include Onebox::Engine
      include Onebox::Engine::JSON

      def initialize(link)
        @url = link
        @options = {}
      end
    end

    it "returns a hash" do
      object = OneboxEngineJSON.new(link).send(:raw)
      expect(object).to be_a(Hash)
    end
  end
end
