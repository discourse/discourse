# frozen_string_literal: true

RSpec.describe Onebox::Engine::HTML do
  before do
    @link = "http://amazon.com"

    stub_request(:get, @link).to_return(status: 200, body: onebox_response("amazon"))
    stub_request(
      :get,
      "https://www.amazon.com/Seven-Languages-Weeks-Programming-Programmers/dp/193435659X",
    ).to_return(status: 200, body: onebox_response("amazon"))
  end

  describe "#raw" do
    class OneboxEngineHTML
      include Onebox::Engine
      include Onebox::Engine::HTML

      def initialize(link)
        @url = link
        @options = {}
      end
    end

    it "returns a Nokogiri object that has a css method" do
      object = OneboxEngineHTML.new("http://amazon.com").send(:raw)
      expect(object).to respond_to(:css)
    end
  end
end
