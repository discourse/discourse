# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::WikipediaOnebox do
  before do
    @link = "http://en.wikipedia.org/wiki/Billy_Jack"

    stub_request(:get, "https://en.wikipedia.org/wiki/Billy_Jack")
      .to_return(status: 200, body: onebox_response(described_class.onebox_name))
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes article image" do
      expect(html).to include("Billy_Jack_poster.jpg")
    end

    it "includes summary" do
      expect(html).to include("Billy Jack is a 1971 action/drama")
    end
  end
end
