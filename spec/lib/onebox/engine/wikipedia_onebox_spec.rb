# frozen_string_literal: true

RSpec.describe Onebox::Engine::WikipediaOnebox do
  let(:wp_link) { "http://en.wikipedia.org/wiki/Billy_Jack" }

  before do
    stub_request(:get, "https://en.wikipedia.org/wiki/Billy_Jack").to_return(
      status: 200,
      body: onebox_response(described_class.onebox_name),
    )
  end

  include_context "with engines" do
    let(:link) { wp_link }
  end
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes article image" do
      expect(html).to include("Billy_Jack_poster.jpg")
    end

    it "includes summary" do
      expect(html).to include("Billy Jack is a 1971 American action drama independent film")
    end
  end

  describe "url with section hash" do
    let(:wp_link) { "http://en.wikipedia.org/wiki/Billy_Jack#Soundtrack" }

    it "includes summary" do
      expect(html).to include("The film score was composed")
    end
  end

  describe "url with url-encoded section hash" do
    let(:wp_link) { "https://fr.wikipedia.org/wiki/Th%C3%A9ologie#L'ontoth%C3%A9ologie" }

    before do
      stub_request(:get, "https://fr.wikipedia.org/wiki/Th%C3%A9ologie").to_return(
        status: 200,
        body: onebox_response("wikipedia_url_encoded"),
      )
    end

    it "includes summary" do
      expect(html).to include("investigation rationnelle sur les substances divines")
    end
  end

  describe ".===" do
    it "matches valid Wikipedia URL with .org" do
      valid_url_org = URI("https://en.wikipedia.org/wiki/Ruby_(programming_language)")
      expect(described_class === valid_url_org).to eq(true)
    end

    it "matches valid Wikipedia URL with .com" do
      valid_url_com = URI("https://en.wikipedia.com/wiki/Ruby_(programming_language)")
      expect(described_class === valid_url_com).to eq(true)
    end

    it "does not match URL with extra domain" do
      malicious_url = URI("https://en.wikipedia.org.malicious.com/wiki/Ruby_(programming_language)")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match unrelated URL" do
      unrelated_url = URI("https://example.com/wiki/wikipedia.org")
      expect(described_class === unrelated_url).to eq(false)
    end
  end
end
