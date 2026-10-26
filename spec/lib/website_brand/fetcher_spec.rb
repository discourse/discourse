# frozen_string_literal: true

RSpec.describe WebsiteBrand::Fetcher do
  subject(:fetcher) { described_class.new }

  let(:url) { "https://brand.example.com/" }

  describe "#text" do
    it "returns the page as UTF-8 along with the URL it ended up at" do
      stub_request(:get, "https://brand.example.com/old").to_return(
        status: 301,
        headers: {
          "Location" => url,
        },
      )
      stub_request(:get, url).to_return(
        body: "caf\xE9".b,
        headers: {
          "Content-Type" => "text/html; charset=iso-8859-1",
        },
      )

      response = fetcher.text("https://brand.example.com/old", max_bytes: 100, accept: "text/html")

      expect(response).to have_attributes(body: "café", url:)
    end

    it "cuts text short at the size limit" do
      stub_request(:get, url).to_return(body: "a" * 100)

      expect(fetcher.text(url, max_bytes: 10, accept: "text/css").body).to eq("a" * 10)
    end

    it "refuses private and internal addresses" do
      FinalDestination::TestHelper.stub_to_fail do
        expect(fetcher.text(url, max_bytes: 100, accept: "text/html")).to be_nil
      end
    end

    it "stops fetching once its time budget is spent" do
      stub_request(:get, url).to_return(body: "page")

      response = described_class.new(time_budget: 0).text(url, max_bytes: 100, accept: "text/html")

      expect(response).to be_nil
      expect(a_request(:get, url)).not_to have_been_made
    end
  end

  describe "#binary" do
    it "skips files over the size limit" do
      stub_request(:get, url).to_return(body: "a" * 100)

      expect(fetcher.binary(url, max_bytes: 10)).to be_nil
      expect(fetcher.binary(url, max_bytes: 100).body).to eq("a" * 100)
    end
  end
end
