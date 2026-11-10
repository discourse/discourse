# frozen_string_literal: true

RSpec.describe Onebox::Engine::GithubBlobOnebox do
  let(:raw_uri) do
    "https://raw.githubusercontent.com/discourse/onebox/master/lib/onebox/engine/github_blob_onebox.rb"
  end

  before do
    stub_request(:get, raw_uri).to_return(
      status: 200,
      body: onebox_response(described_class.onebox_name),
    )
  end

  include_context "with engines" do
    let(:link) do
      "https://github.com/discourse/onebox/blob/master/lib/onebox/engine/github_blob_onebox.rb"
    end
    let(:uri) { URI.parse(link) }
  end
  it_behaves_like "an engine"

  describe "#to_html" do
    it "shows the preview type and repository in the header" do
      header = Nokogiri::HTML5.fragment(html).at_css("aside > header")

      expect(header.at_css(".github-onebox__label").text.strip).to eq("File")
      expect(header.at_css("a").text.strip).to eq("discourse/onebox")
      expect(header.at_css("a")["href"]).to eq(link)
    end

    it "includes file name" do
      expect(html).to include("github_blob_onebox.rb")
    end

    it "includes blob contents" do
      expect(html).to include("module Oneboxer")
    end

    it "does not include blob contents if it is binary" do
      stub_request(:get, raw_uri).to_return(
        status: 200,
        body: File.binread("#{Rails.root.join("spec/fixtures/images/smallest.png")}"),
      )

      expect(html).not_to include("module Oneboxer")
      expect(html).to include("This file is binary.")
      expect(Nokogiri::HTML5.fragment(html).at_css(".github-onebox__label").text.strip).to eq(
        "Binary file",
      )
    end

    context "when github_onebox_access_token is configured" do
      before { SiteSetting.github_onebox_access_tokens = "discourse|github_pat_1234" }

      it "sends it as part of the request" do
        html
        expect(WebMock).to have_requested(:get, raw_uri).with(
          headers: {
            "Authorization" => "Bearer github_pat_1234",
          },
        )
      end
    end
  end
end
