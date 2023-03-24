# frozen_string_literal: true

RSpec.describe Onebox::Helpers do
  describe ".blank?" do
    it { expect(described_class.blank?("")).to be(true) }
    it { expect(described_class.blank?(" ")).to be(true) }
    it { expect(described_class.blank?("test")).to be(false) }
    it { expect(described_class.blank?(%w[test testing])).to be(false) }
    it { expect(described_class.blank?([])).to be(true) }
    it { expect(described_class.blank?({})).to be(true) }
    it { expect(described_class.blank?(nil)).to be(true) }
    it { expect(described_class.blank?(true)).to be(false) }
    it { expect(described_class.blank?(false)).to be(true) }
    it { expect(described_class.blank?(a: "test")).to be(false) }
  end

  describe ".truncate" do
    let(:test_string) { "Chops off on spaces" }
    it { expect(described_class.truncate(test_string)).to eq(test_string) }
    it { expect(described_class.truncate(test_string, 5)).to eq("Chops...") }
    it { expect(described_class.truncate(test_string, 7)).to eq("Chops...") }
    it { expect(described_class.truncate(test_string, 9)).to eq("Chops off...") }
    it { expect(described_class.truncate(test_string, 10)).to eq("Chops off...") }
    it { expect(described_class.truncate(test_string, 100)).to eq("Chops off on spaces") }
    it { expect(described_class.truncate(" #{test_string} ", 6)).to eq(" Chops...") }
  end

  describe "fetch_response" do
    around do |example|
      previous_options = Onebox.options.to_h
      Onebox.options = { max_download_kb: 1 }
      stub_request(:get, "http://example.com/large-file").to_return(
        status: 200,
        body: onebox_response("slides"),
      )

      example.run

      Onebox.options = previous_options
    end

    it "raises an exception when responses are larger than our limit" do
      expect { described_class.fetch_response("http://example.com/large-file") }.to raise_error(
        Onebox::Helpers::DownloadTooLarge,
      )
    end

    it "raises an exception when private url requested" do
      FinalDestination::TestHelper.stub_to_fail do
        expect { described_class.fetch_response("http://example.com/large-file") }.to raise_error(
          FinalDestination::SSRFDetector::DisallowedIpError,
        )
      end
    end
  end

  describe "fetch_html_doc" do
    it "can handle unicode URIs" do
      uri = "https://www.reddit.com/r/UFOs/comments/k18ukd/𝗨𝗙𝗢_𝗱𝗿𝗼𝗽𝘀_𝗰𝗼𝘄_𝘁𝗵𝗿𝗼𝘂𝗴𝗵_𝗯𝗮𝗿𝗻_𝗿𝗼𝗼𝗳/"
      stub_request(:get, uri).to_return(status: 200, body: "<!DOCTYPE html><p>success</p>")

      expect(described_class.fetch_html_doc(uri).to_s).to match("success")
    end

    context "with canonical link" do
      it "follows canonical link" do
        uri = "https://www.example.com"
        stub_request(:get, uri).to_return(
          status: 200,
          body: "<!DOCTYPE html><link rel='canonical' href='http://foobar.com/'/><p>invalid</p>",
        )
        stub_request(:get, "http://foobar.com").to_return(
          status: 200,
          body: "<!DOCTYPE html><p>success</p>",
        )
        stub_request(:head, "http://foobar.com").to_return(status: 200, body: "")

        expect(described_class.fetch_html_doc(uri).to_s).to match("success")
      end

      it "does not follow canonical link pointing at localhost" do
        uri = "https://www.example.com"
        FinalDestination::SSRFDetector
          .stubs(:lookup_ips)
          .with { |h| h == "localhost" }
          .returns(["127.0.0.1"])
        stub_request(:get, uri).to_return(
          status: 200,
          body: "<!DOCTYPE html><link rel='canonical' href='http://localhost/test'/><p>success</p>",
        )

        expect(described_class.fetch_html_doc(uri).to_s).to match("success")
      end
    end
  end

  describe ".fetch_content_length" do
    it "does not connect to private IP" do
      uri = "https://www.example.com"
      FinalDestination::TestHelper.stub_to_fail do
        expect { described_class.fetch_content_length(uri) }.to raise_error(
          FinalDestination::SSRFDetector::DisallowedIpError,
        )
      end
    end
  end

  describe "redirects" do
    describe "redirect limit" do
      before do
        codes = [301, 302, 303, 307, 308]

        (1..6).each do |i|
          code = codes.pop || 302
          stub_request(:get, "https://httpbin.org/redirect/#{i}").to_return(
            status: code,
            body: "",
            headers: {
              location: "https://httpbin.org/redirect/#{i - 1}",
            },
          )
        end

        stub_request(:get, "https://httpbin.org/redirect/0").to_return(
          status: 200,
          body: "<!DOCTYPE html><p>success</p>",
        )
      end

      it "can follow redirects" do
        expect(described_class.fetch_response("https://httpbin.org/redirect/2")).to match("success")
      end

      it "errors on long redirect chains" do
        expect { described_class.fetch_response("https://httpbin.org/redirect/6") }.to raise_error(
          Net::HTTPError,
          /redirect too deep/,
        )
      end
    end

    describe "cookie handling" do
      it "naively forwards cookies to the next request" do
        stub_request(:get, "https://httpbin.org/cookies/set/a/b").to_return(
          status: 302,
          headers: {
            location: "/cookies",
            "set-cookie": "a=b; Path=/",
          },
        )

        stub_request(:get, "https://httpbin.org/cookies").with(
          headers: {
            cookie: "a=b; Path=/",
          },
        ).to_return(status: 200, body: "success, cookie readback not implemented")

        expect(described_class.fetch_response("https://httpbin.org/cookies/set/a/b")).to match(
          "success",
        )
      end

      it "does not send cookies to the wrong domain" do
        skip("unimplemented")

        stub_request(:get, "https://httpbin.org/cookies/set/a/b").to_return(
          status: 302,
          headers: {
            location: "https://evil.com/show_cookies",
            "set-cookie": "a=b; Path=/",
          },
        )

        stub_request(:get, "https://evil.com/show_cookies").with(
          headers: {
            cookie: nil,
          },
        ).to_return(status: 200, body: "success, cookie readback not implemented")

        described_class.fetch_response("https://httpbin.org/cookies/set/a/b")
      end
    end
  end

  describe "user_agent" do
    context "with default" do
      it "has the default Discourse user agent" do
        stub_request(:get, "http://example.com/some-resource").with(
          headers: {
            "user-agent" => /Discourse Forum Onebox/,
          },
        ).to_return(status: 200, body: "test")

        described_class.fetch_response("http://example.com/some-resource")
      end
    end

    context "with custom option" do
      around do |example|
        previous_options = Onebox.options.to_h
        Onebox.options = { user_agent: "EvilTroutBot v0.1" }

        example.run

        Onebox.options = previous_options
      end

      it "has the custom user agent" do
        stub_request(:get, "http://example.com/some-resource").with(
          headers: {
            "user-agent" => "EvilTroutBot v0.1",
          },
        ).to_return(status: 200, body: "test")

        described_class.fetch_response("http://example.com/some-resource")
      end
    end
  end

  describe ".normalize_url_for_output" do
    it do
      expect(described_class.normalize_url_for_output("http://example.com/fo o")).to eq(
        "http://example.com/fo%20o",
      )
    end
    it do
      expect(described_class.normalize_url_for_output("http://example.com/fo'o")).to eq(
        "http://example.com/fo&apos;o",
      )
    end
    it do
      expect(described_class.normalize_url_for_output('http://example.com/fo"o')).to eq(
        "http://example.com/fo&quot;o",
      )
    end
    it do
      expect(described_class.normalize_url_for_output("http://example.com/fo<o>")).to eq(
        "http://example.com/foo",
      )
    end
    it do
      expect(described_class.normalize_url_for_output("http://example.com/d’écran-à")).to eq(
        "http://example.com/d’écran-à",
      )
    end
    it do
      expect(described_class.normalize_url_for_output("//example.com/hello")).to eq(
        "//example.com/hello",
      )
    end
    it { expect(described_class.normalize_url_for_output("example.com/hello")).to eq("") }
    it do
      expect(
        described_class.normalize_url_for_output(
          "linear-gradient(310.77deg, #29AA9F 0%, #098EA6 100%)",
        ),
      ).to eq("")
    end
  end

  describe ".get_absolute_image_url" do
    it do
      expect(
        described_class.get_absolute_image_url(
          "//meta.discourse.org/favicon.ico",
          "https://meta.discourse.org",
        ),
      ).to eq("https://meta.discourse.org/favicon.ico")
    end
    it do
      expect(
        described_class.get_absolute_image_url(
          "http://meta.discourse.org/favicon.ico",
          "https://meta.discourse.org",
        ),
      ).to eq("http://meta.discourse.org/favicon.ico")
    end
    it do
      expect(
        described_class.get_absolute_image_url(
          "https://meta.discourse.org/favicon.ico",
          "https://meta.discourse.org",
        ),
      ).to eq("https://meta.discourse.org/favicon.ico")
    end
    it do
      expect(
        described_class.get_absolute_image_url("/favicon.ico", "https://meta.discourse.org"),
      ).to eq("https://meta.discourse.org/favicon.ico")
    end
    it do
      expect(
        described_class.get_absolute_image_url(
          "/favicon.ico",
          "https://meta.discourse.org/forum/subdir",
        ),
      ).to eq("https://meta.discourse.org/favicon.ico")
    end
    it do
      expect(
        described_class.get_absolute_image_url(
          "../favicon.ico",
          "https://meta.discourse.org/forum/subdir/",
        ),
      ).to eq("https://meta.discourse.org/forum/favicon.ico")
    end
  end

  describe ".uri_encode" do
    it do
      expect(described_class.uri_encode('http://example.com/f"o&o?[b"ar]')).to eq(
        "http://example.com/f%22o&o?%5Bb%22ar%5D",
      )
    end
    it do
      expect(described_class.uri_encode("http://example.com/f.o~o;?<ba'r>")).to eq(
        "http://example.com/f.o~o;?%3Cba%27r%3E",
      )
    end
    it do
      expect(described_class.uri_encode("http://example.com/<pa'th>(foo)?b+a+r")).to eq(
        "http://example.com/%3Cpa'th%3E(foo)?b%2Ba%2Br",
      )
    end
    it do
      expect(described_class.uri_encode("http://example.com/p,a:t!h-f$o@o*?b!a#r@")).to eq(
        "http://example.com/p,a:t!h-f$o@o*?b%21a#r%40",
      )
    end
    it do
      expect(described_class.uri_encode("http://example.com/path&foo?b'a<r>&qu(er)y=1")).to eq(
        "http://example.com/path&foo?b%27a%3Cr%3E&qu%28er%29y=1",
      )
    end
    it do
      expect(
        described_class.uri_encode("http://example.com/index&<script>alert('XSS');</script>"),
      ).to eq("http://example.com/index&%3Cscript%3Ealert('XSS');%3C/script%3E")
    end
    it do
      expect(
        described_class.uri_encode(
          "http://example.com/index.html?message=<script>alert('XSS');</script>",
        ),
      ).to eq(
        "http://example.com/index.html?message=%3Cscript%3Ealert%28%27XSS%27%29%3B%3C%2Fscript%3E",
      )
    end
    it do
      expect(
        described_class.uri_encode(
          "http://example.com/index.php/<IFRAME SRC=source.com onload='alert(document.cookie)'></IFRAME>",
        ),
      ).to eq(
        "http://example.com/index.php/%3CIFRAME%20SRC=source.com%20onload='alert(document.cookie)'%3E%3C/IFRAME%3E",
      )
    end
    it do
      expect(
        described_class.uri_encode("https://en.wiktionary.org/wiki/greengrocer%27s_apostrophe"),
      ).to eq("https://en.wiktionary.org/wiki/greengrocer%27s_apostrophe")
    end

    it do
      expect(
        described_class.uri_encode("https://example.com/random%2Bpath?q=random%2Bquery"),
      ).to eq("https://example.com/random%2Bpath?q=random%2Bquery")
    end
    it do
      expect(described_class.uri_encode("https://glitch.com/edit/#!/equinox-watch")).to eq(
        "https://glitch.com/edit/#!/equinox-watch",
      )
    end
    it do
      expect(
        described_class.uri_encode("https://gitpod.io/#https://github.com/eclipse-theia/theia"),
      ).to eq("https://gitpod.io/#https://github.com/eclipse-theia/theia")
    end
  end
end
