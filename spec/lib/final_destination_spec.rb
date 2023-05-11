# frozen_string_literal: true

require "final_destination"

RSpec.describe FinalDestination do
  let(:opts) do
    {
      ignore_redirects: ["https://ignore-me.com"],
      force_get_hosts: %w[https://force.get.com https://*.ihaveawildcard.com/],
      preserve_fragment_url_hosts: ["https://eviltrout.com"],
    }
  end

  let(:doc_response) { { status: 200, headers: { "Content-Type" => "text/html" } } }

  let(:image_response) { { status: 200, headers: { "Content-Type" => "image/jpeg" } } }

  let(:body_response) { { status: 200, body: "<body>test</body>" } }

  def fd_stub_request(method, url)
    uri = URI.parse(url)

    host = uri.hostname
    ip = "1.2.3.4"

    # In Excon we pass the IP in the URL, so we need to stub
    # that version as well
    uri.hostname = "HOSTNAME_PLACEHOLDER"
    matcher =
      Regexp.escape(uri.to_s).sub(
        "HOSTNAME_PLACEHOLDER",
        "(#{Regexp.escape(host)}|#{Regexp.escape(ip)})",
      )

    stub_request(method, /\A#{matcher}\z/).with(headers: { "Host" => host })
  end

  def canonical_follow(from, dest)
    fd_stub_request(:get, from).to_return(
      status: 200,
      body: "<head><link rel=\"canonical\" href=\"#{dest}\"></head>",
    )
  end

  def redirect_response(from, dest)
    fd_stub_request(:head, from).to_return(status: 302, headers: { "Location" => dest })
  end

  def fd(url)
    FinalDestination.new(url, opts)
  end

  it "correctly parses ignored hostnames" do
    fd =
      FinalDestination.new(
        "https://meta.discourse.org",
        ignore_redirects: %w[http://google.com youtube.com https://meta.discourse.org ://bing.com],
      )

    expect(fd.ignored).to eq(%w[test.localhost google.com meta.discourse.org])
  end

  describe ".resolve" do
    it "has a ready status code before anything happens" do
      expect(fd("https://eviltrout.com").status).to eq(:ready)
    end

    it "returns nil for an invalid url" do
      expect(fd(nil).resolve).to be_nil
      expect(fd("asdf").resolve).to be_nil
    end

    it "returns nil for unresolvable url" do
      FinalDestination::SSRFDetector.stubs(:lookup_ips).raises(SocketError)
      expect(fd("https://example.com").resolve).to eq(nil)
    end

    it "returns nil for url timeout" do
      FinalDestination::SSRFDetector.stubs(:lookup_ips).raises(Timeout::Error)
      expect(fd("https://example.com").resolve).to eq(nil)
    end

    it "returns nil when read timeouts" do
      Excon.expects(:public_send).raises(Excon::Errors::Timeout)

      expect(fd("https://discourse.org").resolve).to eq(nil)
    end

    context "without redirects" do
      before { fd_stub_request(:head, "https://eviltrout.com/").to_return(doc_response) }

      it "returns the final url" do
        final = FinalDestination.new("https://eviltrout.com", opts)
        expect(final.resolve.to_s).to eq("https://eviltrout.com")
        expect(final.redirected?).to eq(false)
        expect(final.status).to eq(:resolved)
      end
    end

    it "ignores redirects" do
      final = FinalDestination.new("https://ignore-me.com/some-url", opts)
      expect(final.resolve.to_s).to eq("https://ignore-me.com/some-url")
      expect(final.redirected?).to eq(false)
      expect(final.status).to eq(:resolved)
    end

    context "with underscores in URLs" do
      before { fd_stub_request(:head, "https://some_thing.example.com").to_return(doc_response) }

      it "doesn't raise errors with underscores in urls" do
        final = FinalDestination.new("https://some_thing.example.com", opts)
        expect(final.resolve.to_s).to eq("https://some_thing.example.com")
        expect(final.redirected?).to eq(false)
        expect(final.status).to eq(:resolved)
      end
    end

    context "with a couple of redirects" do
      before do
        redirect_response("https://eviltrout.com", "https://codinghorror.com/blog")
        redirect_response("https://codinghorror.com/blog", "https://discourse.org")
        fd_stub_request(:head, "https://discourse.org").to_return(doc_response)
      end

      it "returns the final url" do
        final = FinalDestination.new("https://eviltrout.com", opts)
        expect(final.resolve.to_s).to eq("https://discourse.org")
        expect(final.redirected?).to eq(true)
        expect(final.status).to eq(:resolved)
      end
    end

    context "with too many redirects" do
      before do
        redirect_response("https://eviltrout.com", "https://codinghorror.com/blog")
        redirect_response("https://codinghorror.com/blog", "https://discourse.org")
        fd_stub_request(:head, "https://discourse.org").to_return(doc_response)
      end

      it "returns the final url" do
        final = FinalDestination.new("https://eviltrout.com", opts.merge(max_redirects: 1))
        expect(final.resolve).to be_nil
        expect(final.redirected?).to eq(true)
        expect(final.status).to eq(:too_many_redirects)
      end
    end

    context "with a redirect to an internal IP" do
      before do
        redirect_response("https://eviltrout.com", "https://private-host.com")
        FinalDestination::SSRFDetector
          .stubs(:lookup_and_filter_ips)
          .with("eviltrout.com")
          .returns(["1.2.3.4"])
        FinalDestination::SSRFDetector
          .stubs(:lookup_and_filter_ips)
          .with("private-host.com")
          .raises(FinalDestination::SSRFDetector::DisallowedIpError)
      end

      it "returns the final url" do
        final = FinalDestination.new("https://eviltrout.com", opts)
        expect(final.resolve).to be_nil
        expect(final.redirected?).to eq(true)
        expect(final.status).to eq(:invalid_address)
      end
    end

    context "with a redirect to login path" do
      before { redirect_response("https://eviltrout.com/t/xyz/1", "https://eviltrout.com/login") }

      it "does not follow redirect" do
        final = FinalDestination.new("https://eviltrout.com/t/xyz/1", opts)
        expect(final.resolve.to_s).to eq("https://eviltrout.com/t/xyz/1")
        expect(final.redirected?).to eq(false)
        expect(final.status).to eq(:resolved)
      end
    end

    it "raises error when response is too big" do
      stub_const(described_class, "MAX_REQUEST_SIZE_BYTES", 1) do
        fd_stub_request(:get, "https://codinghorror.com/blog").to_return(body_response)
        final =
          FinalDestination.new("https://codinghorror.com/blog", opts.merge(follow_canonical: true))
        expect { final.resolve }.to raise_error(
          Excon::Errors::ExpectationFailed,
          "response size too big: https://codinghorror.com/blog",
        )
      end
    end

    it "raises error when response is too slow" do
      fd_stub_request(:get, "https://codinghorror.com/blog").to_return(
        lambda do |request|
          freeze_time(11.seconds.from_now)
          body_response
        end,
      )
      final =
        FinalDestination.new("https://codinghorror.com/blog", opts.merge(follow_canonical: true))
      expect { final.resolve }.to raise_error(
        Excon::Errors::ExpectationFailed,
        "connect timeout reached: https://codinghorror.com/blog",
      )
    end

    context "when following canonical links" do
      it "resolves the canonical link as the final destination" do
        canonical_follow("https://eviltrout.com", "https://codinghorror.com/blog")
        fd_stub_request(:head, "https://codinghorror.com/blog").to_return(doc_response)

        final = FinalDestination.new("https://eviltrout.com", opts.merge(follow_canonical: true))

        expect(final.resolve.to_s).to eq("https://codinghorror.com/blog")
        expect(final.redirected?).to eq(false)
        expect(final.status).to eq(:resolved)
      end

      it "resolves the canonical link when the URL is relative" do
        host = "https://codinghorror.com"

        canonical_follow("#{host}/blog", "/blog/canonical")
        fd_stub_request(:head, "#{host}/blog/canonical").to_return(doc_response)

        final = FinalDestination.new("#{host}/blog", opts.merge(follow_canonical: true))

        expect(final.resolve.to_s).to eq("#{host}/blog/canonical")
        expect(final.redirected?).to eq(false)
        expect(final.status).to eq(:resolved)
      end

      it "resolves the canonical link when the URL is relative and does not start with the / symbol" do
        host = "https://codinghorror.com"
        canonical_follow("#{host}/blog", "blog/canonical")
        fd_stub_request(:head, "#{host}/blog/canonical").to_return(doc_response)

        final = FinalDestination.new("#{host}/blog", opts.merge(follow_canonical: true))

        expect(final.resolve.to_s).to eq("#{host}/blog/canonical")
        expect(final.redirected?).to eq(false)
        expect(final.status).to eq(:resolved)
      end

      it "does not follow the canonical link if it's the same as the current URL" do
        canonical_follow("https://eviltrout.com", "https://eviltrout.com")

        final = FinalDestination.new("https://eviltrout.com", opts.merge(follow_canonical: true))

        expect(final.resolve.to_s).to eq("https://eviltrout.com")
        expect(final.redirected?).to eq(false)
        expect(final.status).to eq(:resolved)
      end

      it "does not follow the canonical link if it's invalid" do
        canonical_follow("https://eviltrout.com", "")

        final = FinalDestination.new("https://eviltrout.com", opts.merge(follow_canonical: true))

        expect(final.resolve.to_s).to eq("https://eviltrout.com")
        expect(final.redirected?).to eq(false)
        expect(final.status).to eq(:resolved)
      end
    end

    context "when forcing GET" do
      it "will do a GET when forced" do
        url = "https://force.get.com/posts?page=4"
        get_stub = fd_stub_request(:get, url)
        head_stub = fd_stub_request(:head, url)

        final = FinalDestination.new(url, opts)
        expect(final.resolve.to_s).to eq(url)
        expect(final.status).to eq(:resolved)
        expect(get_stub).to have_been_requested
        expect(head_stub).to_not have_been_requested
      end

      it "will do a HEAD if not forced" do
        url = "https://eviltrout.com/posts?page=2"
        get_stub = fd_stub_request(:get, url)
        head_stub = fd_stub_request(:head, url)

        final = FinalDestination.new(url, opts)
        expect(final.resolve.to_s).to eq(url)
        expect(final.status).to eq(:resolved)
        expect(get_stub).to_not have_been_requested
        expect(head_stub).to have_been_requested
      end

      it "will do a GET when forced on a wildcard subdomain" do
        url = "https://any-subdomain.ihaveawildcard.com/some/other/content"
        get_stub = fd_stub_request(:get, url)
        head_stub = fd_stub_request(:head, url)

        final = FinalDestination.new(url, opts)
        expect(final.resolve.to_s).to eq(url)
        expect(final.status).to eq(:resolved)
        expect(get_stub).to have_been_requested
        expect(head_stub).to_not have_been_requested
      end

      it "will do a HEAD if on a subdomain of a forced get domain without a wildcard" do
        url = "https://particularly.eviltrout.com/has/a/secret/plan"
        get_stub = fd_stub_request(:get, url)
        head_stub = fd_stub_request(:head, url)

        final = FinalDestination.new(url, opts)
        expect(final.resolve.to_s).to eq(url)
        expect(final.status).to eq(:resolved)
        expect(get_stub).to_not have_been_requested
        expect(head_stub).to have_been_requested
      end
    end

    context "when HEAD not supported" do
      before do
        fd_stub_request(:get, "https://eviltrout.com").to_return(
          status: 301,
          headers: {
            "Location" => "https://discourse.org",
            "Set-Cookie" => "evil=trout",
          },
        )
        fd_stub_request(:head, "https://discourse.org")
      end

      context "when the status code is 405" do
        before { fd_stub_request(:head, "https://eviltrout.com").to_return(status: 405) }

        it "will try a GET" do
          final = FinalDestination.new("https://eviltrout.com", opts)
          expect(final.resolve.to_s).to eq("https://discourse.org")
          expect(final.status).to eq(:resolved)
          expect(final.cookie).to eq("evil=trout")
        end
      end

      context "when the status code is 501" do
        before { fd_stub_request(:head, "https://eviltrout.com").to_return(status: 501) }

        it "will try a GET" do
          final = FinalDestination.new("https://eviltrout.com", opts)
          expect(final.resolve.to_s).to eq("https://discourse.org")
          expect(final.status).to eq(:resolved)
          expect(final.cookie).to eq("evil=trout")
        end
      end

      it "correctly extracts cookies during GET" do
        fd_stub_request(:head, "https://eviltrout.com").to_return(status: 405)

        fd_stub_request(:get, "https://eviltrout.com").to_return(
          status: 302,
          body: "",
          headers: {
            "Location" => "https://eviltrout.com",
            "Set-Cookie" => [
              "foo=219ffwef9w0f; expires=Mon, 19-Feb-2018 10:44:24 GMT; path=/; domain=eviltrout.com",
              "bar=1",
              "baz=2; expires=Tue, 19-Feb-2019 10:14:24 GMT; path=/; domain=eviltrout.com",
            ],
          },
        )

        fd_stub_request(:head, "https://eviltrout.com").with(
          headers: {
            "Cookie" => "bar=1; baz=2; foo=219ffwef9w0f",
          },
        )

        final = FinalDestination.new("https://eviltrout.com", opts)
        expect(final.resolve.to_s).to eq("https://eviltrout.com")
        expect(final.status).to eq(:resolved)
        expect(final.cookie).to eq("bar=1; baz=2; foo=219ffwef9w0f")
      end
    end

    it "should use the correct format for cookies when there is only one cookie" do
      fd_stub_request(:head, "https://eviltrout.com").to_return(
        status: 302,
        headers: {
          "Location" => "https://eviltrout.com",
          "Set-Cookie" =>
            "foo=219ffwef9w0f; expires=Mon, 19-Feb-2018 10:44:24 GMT; path=/; domain=eviltrout.com",
        },
      )

      fd_stub_request(:head, "https://eviltrout.com").with(
        headers: {
          "Cookie" => "foo=219ffwef9w0f",
        },
      )

      final = FinalDestination.new("https://eviltrout.com", opts)
      expect(final.resolve.to_s).to eq("https://eviltrout.com")
      expect(final.status).to eq(:resolved)
      expect(final.cookie).to eq("foo=219ffwef9w0f")
    end

    it "should use the correct format for cookies when there are multiple cookies" do
      fd_stub_request(:head, "https://eviltrout.com").to_return(
        status: 302,
        headers: {
          "Location" => "https://eviltrout.com",
          "Set-Cookie" => [
            "foo=219ffwef9w0f; expires=Mon, 19-Feb-2018 10:44:24 GMT; path=/; domain=eviltrout.com",
            "bar=1",
            "baz=2; expires=Tue, 19-Feb-2019 10:14:24 GMT; path=/; domain=eviltrout.com",
          ],
        },
      )

      fd_stub_request(:head, "https://eviltrout.com").with(
        headers: {
          "Cookie" => "bar=1; baz=2; foo=219ffwef9w0f",
        },
      )

      final = FinalDestination.new("https://eviltrout.com", opts)
      expect(final.resolve.to_s).to eq("https://eviltrout.com")
      expect(final.status).to eq(:resolved)
      expect(final.cookie).to eq("bar=1; baz=2; foo=219ffwef9w0f")
    end

    it "persists fragment url" do
      origin_url = "https://eviltrout.com/origin/lib/code/foobar.rb"
      upstream_url = "https://eviltrout.com/upstream/lib/code/foobar.rb"

      redirect_response(origin_url, upstream_url)
      fd_stub_request(:head, upstream_url).to_return(doc_response)

      final = FinalDestination.new("#{origin_url}#L154-L205", opts)
      expect(final.resolve.to_s).to eq("#{upstream_url}#L154-L205")
      expect(final.status).to eq(:resolved)
    end

    context "with content_type" do
      before do
        fd_stub_request(:head, "https://eviltrout.com/this/is/an/image").to_return(image_response)
      end

      it "returns a content_type" do
        final = FinalDestination.new("https://eviltrout.com/this/is/an/image", opts)
        expect(final.resolve.to_s).to eq("https://eviltrout.com/this/is/an/image")
        expect(final.content_type).to eq("image/jpeg")
        expect(final.status).to eq(:resolved)
      end
    end
  end

  describe "#get" do
    let(:fd) { FinalDestination.new("http://wikipedia.com", opts.merge(verbose: true)) }

    before { described_class.clear_https_cache!("wikipedia.com") }

    context "when there is a redirect" do
      before do
        stub_request(:get, "http://wikipedia.com/").to_return(
          status: 302,
          body: "",
          headers: {
            "location" => "https://wikipedia.com/",
          },
        )
        # webmock does not do chunks
        stub_request(:get, "https://wikipedia.com/").to_return(
          status: 200,
          body: "<html><head>",
          headers: {
          },
        )
      end

      after { WebMock.reset! }

      it "correctly streams" do
        chunk = nil
        result =
          fd.get do |resp, c|
            chunk = c
            throw :done
          end

        expect(result).to eq("https://wikipedia.com/")
        expect(chunk).to eq("<html><head>")
      end
    end

    context "when there is a timeout" do
      subject(:get) { fd.get {} }

      before { fd.stubs(:safe_session).raises(Timeout::Error) }

      it "logs the exception" do
        Rails
          .logger
          .expects(:warn)
          .with(regexp_matches(/FinalDestination could not resolve URL \(timeout\)/))
        get
      end

      it "returns nothing" do
        expect(get).to be_blank
      end
    end

    context "when there is an SSL error" do
      subject(:get) { fd.get {} }

      before { fd.stubs(:safe_session).raises(OpenSSL::SSL::SSLError) }

      it "logs the exception" do
        Rails.logger.expects(:warn).with(regexp_matches(/an error with ssl occurred/i))
        get
      end

      it "returns nothing" do
        expect(get).to be_blank
      end
    end
  end

  describe ".validate_url_format" do
    it "supports http urls" do
      expect(fd("http://eviltrout.com").validate_uri_format).to eq(true)
    end

    it "supports https urls" do
      expect(fd("https://eviltrout.com").validate_uri_format).to eq(true)
    end

    it "doesn't support ftp urls" do
      expect(fd("ftp://eviltrout.com").validate_uri_format).to eq(false)
    end

    it "doesn't support IP urls" do
      expect(fd("http://104.25.152.10").validate_uri_format).to eq(false)
      expect(fd("https://[2001:abc:de:01:0:3f0:6a65:c2bf]").validate_uri_format).to eq(false)
    end

    it "returns false for schemeless URL" do
      expect(fd("eviltrout.com").validate_uri_format).to eq(false)
    end

    it "returns false for nil URL" do
      expect(fd(nil).validate_uri_format).to eq(false)
    end

    it "returns false for invalid ports" do
      expect(fd("http://eviltrout.com:21").validate_uri_format).to eq(false)
      expect(fd("https://eviltrout.com:8000").validate_uri_format).to eq(false)
    end

    it "returns true for valid ports" do
      expect(fd("http://eviltrout.com:80").validate_uri_format).to eq(true)
      expect(fd("https://eviltrout.com:443").validate_uri_format).to eq(true)
    end
  end

  describe "https cache" do
    it "will cache https lookups" do
      FinalDestination.clear_https_cache!("wikipedia.com")

      fd_stub_request(:head, "http://wikipedia.com/image.png").to_return(
        status: 302,
        body: "",
        headers: {
          location: "https://wikipedia.com/image.png",
        },
      )

      fd_stub_request(:head, "https://wikipedia.com/image.png")

      fd("http://wikipedia.com/image.png").resolve

      fd_stub_request(:head, "https://wikipedia.com/image2.png")

      fd("http://wikipedia.com/image2.png").resolve
    end
  end

  describe "#normalized_url" do
    it "correctly normalizes url" do
      fragment_url =
        "https://eviltrout.com/2016/02/25/fixing-android-performance.html#discourse-comments"

      expect(fd(fragment_url).normalized_url.to_s).to eq(fragment_url)

      expect(fd("https://eviltrout.com?s=180&#038;d=mm&#038;r=g").normalized_url.to_s).to eq(
        "https://eviltrout.com?s=180&#038;d=mm&%23038;r=g",
      )

      expect(fd("http://example.com/?a=\11\15").normalized_url.to_s).to eq(
        "http://example.com/?a=%09%0D",
      )

      expect(
        fd("https://ru.wikipedia.org/wiki/%D0%A1%D0%B2%D0%BE%D0%B1%D0%BE").normalized_url.to_s,
      ).to eq("https://ru.wikipedia.org/wiki/%D0%A1%D0%B2%D0%BE%D0%B1%D0%BE")

      expect(fd("https://ru.wikipedia.org/wiki/Свобо").normalized_url.to_s).to eq(
        "https://ru.wikipedia.org/wiki/%D0%A1%D0%B2%D0%BE%D0%B1%D0%BE",
      )
    end
  end
end
