# frozen_string_literal: true

require "rails_helper"
require "onebox_helper"

describe Onebox::Engine::HTML do
  before(:all) do
    @link = "http://amazon.com"
    fake(@link, onebox_response("amazon"))
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
