# frozen_string_literal: true

RSpec.describe Onebox::Engine::WikipediaOnebox do
  before do
    @link = "http://en.wikipedia.org/wiki/Billy_Jack"

    stub_request(:get, "https://en.wikipedia.org/wiki/Billy_Jack").to_return(
      status: 200,
      body: onebox_response(described_class.onebox_name),
    )
  end

  include_context "with engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes article image" do
      expect(html).to include("Billy_Jack_poster.jpg")
    end

    it "includes summary" do
      expect(html).to include("Billy Jack is a 1971 action/drama")
    end
  end

  describe "url with section hash" do
    before { @link = "http://en.wikipedia.org/wiki/Billy_Jack#Soundtrack" }

    it "includes summary" do
      expect(html).to include("The film score was composed")
    end
  end

  describe "url with url-encoded section hash" do
    before do
      @link = "https://fr.wikipedia.org/wiki/Th%C3%A9ologie#La_th%C3%A9ologie_selon_Aristote"

      stub_request(:get, "https://fr.wikipedia.org/wiki/Th%C3%A9ologie").to_return(
        status: 200,
        body: onebox_response("wikipedia_url_encoded"),
      )
    end

    it "includes summary" do
      expect(html).to include("Le terme est repris par")
    end
  end
end
