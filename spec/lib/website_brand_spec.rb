# frozen_string_literal: true

RSpec.describe WebsiteBrand do
  describe ".profile" do
    let(:url) { "https://brand.example.com/" }
    let(:page) do
      {
        body: '<meta name="theme-color" content="#635bff">',
        headers: {
          "Content-Type" => "text/html",
        },
      }
    end

    before { stub_request(:get, /.*/).to_return(status: 404) }

    it "keeps a profile for a day" do
      stub_request(:get, url).to_return(page)

      expect(described_class.profile(url).brand).to eq("635bff")
      expect(described_class.profile(url).brand).to eq("635bff")
      expect(a_request(:get, url)).to have_been_made.once
    end

    it "tries again when a site couldn't be read" do
      stub_request(:get, url).to_return({ status: 500 }, page)

      expect(described_class.profile(url)).to be_nil
      expect(described_class.profile(url).brand).to eq("635bff")
    end

    it "only reads http and https URLs" do
      expect(described_class.profile("ftp://brand.example.com/")).to be_nil
      expect(described_class.profile("javascript:alert(1)")).to be_nil
      expect(a_request(:any, /.*/)).not_to have_been_made
    end
  end
end
