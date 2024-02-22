# frozen_string_literal: true

RSpec.describe RetrieveTitle do
  describe ".extract_title" do
    it "will extract the value from the title tag" do
      title = RetrieveTitle.extract_title("<html><title>My Cool Title</title></html>")

      expect(title).to eq("My Cool Title")
    end

    it "will strip whitespace" do
      title = RetrieveTitle.extract_title("<html><title>   Another Title\n\n </title></html>")

      expect(title).to eq("Another Title")
    end

    it "will pick og:title if title is missing" do
      title = RetrieveTitle.extract_title(<<~HTML)
        <html>
          <meta property="og:title" content="Good Title"
        </html>
        HTML

      expect(title).to eq("Good Title")
    end

    it "will prefer the title over the opengraph tag" do
      title = RetrieveTitle.extract_title(<<~HTML)
        <html>
          <title>Good Title</title>
          <meta property="og:title" content="Bad Title"
        </html>
        HTML

      expect(title).to eq("Good Title")
    end

    it "will parse a YouTube url from javascript" do
      title = RetrieveTitle.extract_title(<<~HTML)
        <html>
          <title>YouTube</title>
          <script>document.title = "Video Title";</script>
        </html>
        HTML
      expect(title).to eq("Video Title")
    end

    it "will not exception out for invalid html" do
      attributes = (1..1000).map { |x| " attr#{x}='1' " }.join
      title = RetrieveTitle.extract_title <<~HTML
        <html>
          <title>test</title>
          <body #{attributes}>
        </html>
      HTML

      expect(title).to eq(nil)
    end
  end

  describe ".crawl" do
    it "can properly extract a title from a url" do
      stub_request(:get, "https://brelksdjflaskfj.com/amazing").to_return(
        status: 200,
        body: "<html><title>very amazing</title>",
      )

      # we still resolve the IP address for every host
      IPSocket.stubs(:getaddress).returns("100.2.3.4")

      expect(RetrieveTitle.crawl("https://brelksdjflaskfj.com/amazing")).to eq("very amazing")
    end

    it "detects and uses encoding from Content-Type header" do
      stub_request(:get, "https://brelksdjflaskfj.com/amazing").to_return(
        status: 200,
        body: "<html><title>fancy apostrophes ’’’</title>".dup.force_encoding("ASCII-8BIT"),
        headers: {
          "Content-Type" => 'text/html; charset="utf-8"',
        },
      )

      IPSocket.stubs(:getaddress).returns("100.2.3.4")
      expect(RetrieveTitle.crawl("https://brelksdjflaskfj.com/amazing")).to eq(
        "fancy apostrophes ’’’",
      )

      stub_request(:get, "https://brelksdjflaskfj.com/amazing").to_return(
        status: 200,
        body:
          "<html><title>japanese こんにちは website</title>".encode("EUC-JP").force_encoding(
            "ASCII-8BIT",
          ),
        headers: {
          "Content-Type" => "text/html;charset=euc-jp",
        },
      )

      IPSocket.stubs(:getaddress).returns("100.2.3.4")
      expect(RetrieveTitle.crawl("https://brelksdjflaskfj.com/amazing")).to eq(
        "japanese こんにちは website",
      )
    end

    it "can follow redirect" do
      stub_request(:get, "http://foobar.com/amazing").to_return(
        status: 301,
        body: "",
        headers: {
          "location" => "https://wikipedia.com/amazing",
        },
      )

      stub_request(:get, "https://wikipedia.com/amazing").to_return(
        status: 200,
        body: "<html><title>very amazing</title>",
        headers: {
        },
      )

      IPSocket.stubs(:getaddress).returns("100.2.3.4")
      expect(RetrieveTitle.crawl("http://foobar.com/amazing")).to eq("very amazing")
    end

    it "returns empty title if redirect uri is in blacklist" do
      SiteSetting.blocked_onebox_domains = "wikipedia.com"

      stub_request(:get, "http://foobar.com/amazing").to_return(
        status: 301,
        body: "",
        headers: {
          "location" => "https://wikipedia.com/amazing",
        },
      )

      stub_request(:get, "https://wikipedia.com/amazing").to_return(
        status: 200,
        body: "<html><title>very amazing</title>",
        headers: {
        },
      )

      expect(RetrieveTitle.crawl("http://foobar.com/amazing")).to eq(nil)
    end

    it "doesn't return title if a blocked domain is encountered anywhere in the redirect chain" do
      SiteSetting.blocked_onebox_domains = "wikipedia.com"

      stub_request(:get, "http://foobar.com/amazing").to_return(
        status: 301,
        body: "",
        headers: {
          "location" => "https://wikipedia.com/amazing",
        },
      )

      stub_request(:get, "https://wikipedia.com/amazing").to_return(
        status: 301,
        body: "",
        headers: {
          "location" => "https://cat.com/meow",
        },
      )

      stub_request(:get, "https://cat.com/meow").to_return(
        status: 200,
        body: "<html><title>very amazing</title>",
        headers: {
        },
      )

      expect(RetrieveTitle.crawl("http://foobar.com/amazing")).to be_blank
    end

    it "doesn't return title if the Discourse-No-Onebox header == 1" do
      stub_request(:get, "https://cat.com/meow/no-onebox").to_return(
        status: 200,
        body: "<html><title>discourse stay away</title>",
        headers: {
          "Discourse-No-Onebox" => "1",
        },
      )

      expect(RetrieveTitle.crawl("https://cat.com/meow/no-onebox")).to be_blank
    end

    it "doesn't return a title if response is unsuccessful" do
      stub_request(:get, "https://example.com").to_return(status: 404, body: "")

      expect(RetrieveTitle.crawl("https://example.com")).to eq(nil)
    end

    it "it raises errors other than Net::ReadTimeout, e.g. NoMethodError" do
      stub_request(:get, "https://example.com").to_raise(NoMethodError)

      expect { RetrieveTitle.crawl("https://example.com") }.to raise_error(NoMethodError)
    end

    it "it ignores Net::ReadTimeout errors" do
      stub_request(:get, "https://example.com").to_raise(Net::ReadTimeout)

      expect(RetrieveTitle.crawl("https://example.com")).to eq(nil)
    end

    it "ignores SSRF lookup errors" do
      described_class.stubs(:fetch_title).raises(FinalDestination::SSRFDetector::LookupFailedError)

      expect(RetrieveTitle.crawl("https://example.com")).to eq(nil)
    end

    it "ignores URL encoding errors" do
      described_class.stubs(:fetch_title).raises(FinalDestination::UrlEncodingError)

      expect(RetrieveTitle.crawl("https://example.com")).to eq(nil)
    end
  end

  describe ".fetch_title" do
    it "does not parse broken title tag" do
      # webmock does not do chunks
      stub_request(:get, "https://en.wikipedia.org/wiki/Internet").to_return(
        status: 200,
        body: "<html><head><title>Internet - Wikipedia</ti",
        headers: {
        },
      )

      title = RetrieveTitle.fetch_title("https://en.wikipedia.org/wiki/Internet")
      expect(title).to eq(nil)
    end

    it "can parse correct title tag" do
      # webmock does not do chunks
      stub_request(:get, "https://en.wikipedia.org/wiki/Internet").to_return(
        status: 200,
        body: "<html><head><title>Internet - Wikipedia</title>",
        headers: {
        },
      )

      title = RetrieveTitle.fetch_title("https://en.wikipedia.org/wiki/Internet")
      expect(title).to eq("Internet - Wikipedia")
    end
  end
end
