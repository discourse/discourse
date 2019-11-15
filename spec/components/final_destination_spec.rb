# frozen_string_literal: true

require 'rails_helper'
require 'final_destination'

describe FinalDestination do

  let(:opts) do
    {
      ignore_redirects: ['https://ignore-me.com'],

      force_get_hosts: ['https://force.get.com'],

      preserve_fragment_url_hosts: ['https://eviltrout.com'],

      # avoid IP lookups in test
      lookup_ip: lambda do |host|
        case host
        when 'eviltrout.com' then '52.84.143.152'
        when 'codinghorror.com' then '91.146.108.148'
        when 'discourse.org' then '104.25.152.10'
        when 'some_thing.example.com' then '104.25.152.10'
        when 'private-host.com' then '192.168.10.1'
        when 'internal-ipv6.com' then '2001:abc:de:01:3:3d0:6a65:c2bf'
        when 'ignore-me.com' then '53.84.143.152'
        when 'force.get.com' then '22.102.29.40'
        when 'wikipedia.com' then '1.2.3.4'
        else
          as_ip = IPAddr.new(host)
          host
        end
      end
    }
  end

  let(:doc_response) do
    {
      status: 200,
      headers: { "Content-Type" => "text/html" }
    }
  end

  def redirect_response(from, dest)
    stub_request(:head, from).to_return(
      status: 302,
      headers: { "Location" => dest }
    )
  end

  def fd(url)
    FinalDestination.new(url, opts)
  end

  it 'correctly parses ignored hostnames' do
    fd = FinalDestination.new('https://meta.discourse.org',
      ignore_redirects: ['http://google.com', 'youtube.com', 'https://meta.discourse.org', '://bing.com']
    )

    expect(fd.ignored).to eq(['test.localhost', 'google.com', 'meta.discourse.org'])
  end

  describe '.resolve' do

    it "has a ready status code before anything happens" do
      expect(fd('https://eviltrout.com').status).to eq(:ready)
    end

    it "returns nil for an invalid url" do
      expect(fd(nil).resolve).to be_nil
      expect(fd('asdf').resolve).to be_nil
    end

    it "returns nil when read timeouts" do
      Excon.expects(:public_send).raises(Excon::Errors::Timeout)

      expect(fd('https://discourse.org').resolve).to eq(nil)
    end

    context "without redirects" do
      before do
        stub_request(:head, "https://eviltrout.com").to_return(doc_response)
      end

      it "returns the final url" do
        final = FinalDestination.new('https://eviltrout.com', opts)
        expect(final.resolve.to_s).to eq('https://eviltrout.com')
        expect(final.redirected?).to eq(false)
        expect(final.status).to eq(:resolved)
      end
    end

    it "ignores redirects" do
      final = FinalDestination.new('https://ignore-me.com/some-url', opts)
      expect(final.resolve.to_s).to eq('https://ignore-me.com/some-url')
      expect(final.redirected?).to eq(false)
      expect(final.status).to eq(:resolved)
    end

    context "underscores in URLs" do
      before do
        stub_request(:head, 'https://some_thing.example.com').to_return(doc_response)
      end

      it "doesn't raise errors with underscores in urls" do
        final = FinalDestination.new('https://some_thing.example.com', opts)
        expect(final.resolve.to_s).to eq('https://some_thing.example.com')
        expect(final.redirected?).to eq(false)
        expect(final.status).to eq(:resolved)
      end
    end

    context "with a couple of redirects" do
      before do
        redirect_response("https://eviltrout.com", "https://codinghorror.com/blog")
        redirect_response("https://codinghorror.com/blog", "https://discourse.org")
        stub_request(:head, "https://discourse.org").to_return(doc_response)
      end

      it "returns the final url" do
        final = FinalDestination.new('https://eviltrout.com', opts)
        expect(final.resolve.to_s).to eq('https://discourse.org')
        expect(final.redirected?).to eq(true)
        expect(final.status).to eq(:resolved)
      end
    end

    context "with too many redirects" do
      before do
        redirect_response("https://eviltrout.com", "https://codinghorror.com/blog")
        redirect_response("https://codinghorror.com/blog", "https://discourse.org")
        stub_request(:head, "https://discourse.org").to_return(doc_response)
      end

      it "returns the final url" do
        final = FinalDestination.new('https://eviltrout.com', opts.merge(max_redirects: 1))
        expect(final.resolve).to be_nil
        expect(final.redirected?).to eq(true)
        expect(final.status).to eq(:too_many_redirects)
      end
    end

    context "with a redirect to an internal IP" do
      before do
        redirect_response("https://eviltrout.com", "https://private-host.com")
        stub_request(:head, "https://private-host.com").to_return(doc_response)
      end

      it "returns the final url" do
        final = FinalDestination.new('https://eviltrout.com', opts)
        expect(final.resolve).to be_nil
        expect(final.redirected?).to eq(true)
        expect(final.status).to eq(:invalid_address)
      end
    end

    context "with a redirect to login path" do
      before do
        redirect_response("https://eviltrout.com/t/xyz/1", "https://eviltrout.com/login")
      end

      it "does not follow redirect" do
        final = FinalDestination.new('https://eviltrout.com/t/xyz/1', opts)
        expect(final.resolve.to_s).to eq('https://eviltrout.com/t/xyz/1')
        expect(final.redirected?).to eq(false)
        expect(final.status).to eq(:resolved)
      end
    end

    context "GET can be forced" do
      before do
        stub_request(:head, 'https://force.get.com/posts?page=4')
        stub_request(:get, 'https://force.get.com/posts?page=4')
        stub_request(:head, 'https://eviltrout.com/posts?page=2')
        stub_request(:get, 'https://eviltrout.com/posts?page=2')
      end

      it "will do a GET when forced" do
        final = FinalDestination.new('https://force.get.com/posts?page=4', opts)
        expect(final.resolve.to_s).to eq('https://force.get.com/posts?page=4')
        expect(final.status).to eq(:resolved)
        expect(WebMock).to have_requested(:get, 'https://force.get.com/posts?page=4')
        expect(WebMock).to_not have_requested(:head, 'https://force.get.com/posts?page=4')
      end

      it "will do a HEAD if not forced" do
        final = FinalDestination.new('https://eviltrout.com/posts?page=2', opts)
        expect(final.resolve.to_s).to eq('https://eviltrout.com/posts?page=2')
        expect(final.status).to eq(:resolved)
        expect(WebMock).to_not have_requested(:get, 'https://eviltrout.com/posts?page=2')
        expect(WebMock).to have_requested(:head, 'https://eviltrout.com/posts?page=2')
      end
    end

    context "HEAD not supported" do
      before do
        stub_request(:get, 'https://eviltrout.com').to_return(
          status: 301,
          headers: {
            "Location" => 'https://discourse.org',
            'Set-Cookie' => 'evil=trout'
          }
        )
        stub_request(:head, 'https://discourse.org')
      end

      context "when the status code is 405" do
        before do
          stub_request(:head, 'https://eviltrout.com').to_return(status: 405)
        end

        it "will try a GET" do
          final = FinalDestination.new('https://eviltrout.com', opts)
          expect(final.resolve.to_s).to eq('https://discourse.org')
          expect(final.status).to eq(:resolved)
          expect(final.cookie).to eq('evil=trout')
        end
      end

      context "when the status code is 501" do
        before do
          stub_request(:head, 'https://eviltrout.com').to_return(status: 501)
        end

        it "will try a GET" do
          final = FinalDestination.new('https://eviltrout.com', opts)
          expect(final.resolve.to_s).to eq('https://discourse.org')
          expect(final.status).to eq(:resolved)
          expect(final.cookie).to eq('evil=trout')
        end
      end

      it "correctly extracts cookies during GET" do
        stub_request(:head, "https://eviltrout.com").to_return(status: 405)

        stub_request(:get, "https://eviltrout.com")
          .to_return(status: 302, body: "" , headers: {
            "Location" => "https://eviltrout.com",
            "Set-Cookie" => ["foo=219ffwef9w0f; expires=Mon, 19-Feb-2018 10:44:24 GMT; path=/; domain=eviltrout.com",
                             "bar=1",
                             "baz=2; expires=Tue, 19-Feb-2019 10:14:24 GMT; path=/; domain=eviltrout.com"]
          })

        stub_request(:head, "https://eviltrout.com")
          .with(headers: { "Cookie" => "bar=1; baz=2; foo=219ffwef9w0f" })

        final = FinalDestination.new("https://eviltrout.com", opts)
        expect(final.resolve.to_s).to eq("https://eviltrout.com")
        expect(final.status).to eq(:resolved)
        expect(final.cookie).to eq("bar=1; baz=2; foo=219ffwef9w0f")
      end
    end

    it "should use the correct format for cookies when there is only one cookie" do
      stub_request(:head, "https://eviltrout.com")
        .to_return(status: 302, headers: {
          "Location" => "https://eviltrout.com",
          "Set-Cookie" => "foo=219ffwef9w0f; expires=Mon, 19-Feb-2018 10:44:24 GMT; path=/; domain=eviltrout.com"
        })

      stub_request(:head, "https://eviltrout.com")
        .with(headers: { "Cookie" => "foo=219ffwef9w0f" })

      final = FinalDestination.new("https://eviltrout.com", opts)
      expect(final.resolve.to_s).to eq("https://eviltrout.com")
      expect(final.status).to eq(:resolved)
      expect(final.cookie).to eq("foo=219ffwef9w0f")
    end

    it "should use the correct format for cookies when there are multiple cookies" do
      stub_request(:head, "https://eviltrout.com")
        .to_return(status: 302, headers: {
          "Location" => "https://eviltrout.com",
          "Set-Cookie" => ["foo=219ffwef9w0f; expires=Mon, 19-Feb-2018 10:44:24 GMT; path=/; domain=eviltrout.com",
                           "bar=1",
                           "baz=2; expires=Tue, 19-Feb-2019 10:14:24 GMT; path=/; domain=eviltrout.com"]
        })

      stub_request(:head, "https://eviltrout.com")
        .with(headers: { "Cookie" => "bar=1; baz=2; foo=219ffwef9w0f" })

      final = FinalDestination.new("https://eviltrout.com", opts)
      expect(final.resolve.to_s).to eq("https://eviltrout.com")
      expect(final.status).to eq(:resolved)
      expect(final.cookie).to eq("bar=1; baz=2; foo=219ffwef9w0f")
    end

    it "persists fragment url" do
      origin_url = "https://eviltrout.com/origin/lib/code/foobar.rb"
      upstream_url = "https://eviltrout.com/upstream/lib/code/foobar.rb"

      redirect_response(origin_url, upstream_url)
      stub_request(:head, upstream_url).to_return(doc_response)

      final = FinalDestination.new("#{origin_url}#L154-L205", opts)
      expect(final.resolve.to_s).to eq("#{upstream_url}#L154-L205")
      expect(final.status).to eq(:resolved)
    end
  end

  describe '.get' do

    it "can correctly stream with a redirect" do
      FinalDestination.clear_https_cache!("wikipedia.com")

      stub_request(:get, "http://wikipedia.com/").
        to_return(status: 302, body: "" , headers: { "location" => "https://wikipedia.com/" })

      # webmock does not do chunks
      stub_request(:get, "https://wikipedia.com/").
        to_return(status: 200, body: "<html><head>" , headers: {})

      result = nil
      chunk = nil

      result = FinalDestination.new("http://wikipedia.com", opts).get do |resp, c|
        chunk = c
        throw :done
      end

      expect(result).to eq("https://wikipedia.com/")
      expect(chunk).to eq("<html><head>")
    end
  end

  describe '.validate_uri' do
    context "host lookups" do
      it "works for various hosts" do
        expect(fd('https://private-host.com').validate_uri).to eq(false)
        expect(fd('https://eviltrout.com:443').validate_uri).to eq(true)
      end
    end
  end

  describe ".validate_url_format" do
    it "supports http urls" do
      expect(fd('http://eviltrout.com').validate_uri_format).to eq(true)
    end

    it "supports https urls" do
      expect(fd('https://eviltrout.com').validate_uri_format).to eq(true)
    end

    it "doesn't support ftp urls" do
      expect(fd('ftp://eviltrout.com').validate_uri_format).to eq(false)
    end

    it "doesn't support IP urls" do
      expect(fd('http://104.25.152.10').validate_uri_format).to eq(false)
      expect(fd('https://[2001:abc:de:01:0:3f0:6a65:c2bf]').validate_uri_format).to eq(false)
    end

    it "returns false for schemeless URL" do
      expect(fd('eviltrout.com').validate_uri_format).to eq(false)
    end

    it "returns false for nil URL" do
      expect(fd(nil).validate_uri_format).to eq(false)
    end

    it "returns false for invalid ports" do
      expect(fd('http://eviltrout.com:21').validate_uri_format).to eq(false)
      expect(fd('https://eviltrout.com:8000').validate_uri_format).to eq(false)
    end

    it "returns true for valid ports" do
      expect(fd('http://eviltrout.com:80').validate_uri_format).to eq(true)
      expect(fd('https://eviltrout.com:443').validate_uri_format).to eq(true)
    end
  end

  describe ".is_dest_valid" do
    it "returns false for a valid ipv4" do
      expect(fd("https://52.84.143.67").is_dest_valid?).to eq(true)
      expect(fd("https://104.25.153.10").is_dest_valid?).to eq(true)
    end

    it "returns false for short ip" do
      lookup = lambda do |host|
        # How IPs are looked up for single digits
        if host == "0"
          "0.0.0.0"
        elsif host == "1"
          "0.0.0.1"
        end
      end

      expect(FinalDestination.new('https://0/logo.png', lookup_ip: lookup).is_dest_valid?).to eq(false)
      expect(FinalDestination.new('https://1/logo.png', lookup_ip: lookup).is_dest_valid?).to eq(false)
    end

    it "returns false for private ipv4" do
      expect(fd("https://127.0.0.1").is_dest_valid?).to eq(false)
      expect(fd("https://192.168.1.3").is_dest_valid?).to eq(false)
      expect(fd("https://10.0.0.5").is_dest_valid?).to eq(false)
      expect(fd("https://172.16.0.1").is_dest_valid?).to eq(false)
    end

    it "returns false for IPV6 via site settings" do
      SiteSetting.blacklist_ip_blocks = '2001:abc:de::/48|2002:abc:de::/48'
      expect(fd('https://[2001:abc:de:01:0:3f0:6a65:c2bf]').is_dest_valid?).to eq(false)
      expect(fd('https://[2002:abc:de:01:0:3f0:6a65:c2bf]').is_dest_valid?).to eq(false)
      expect(fd('https://internal-ipv6.com').is_dest_valid?).to eq(false)
      expect(fd('https://[2003:abc:de:01:0:3f0:6a65:c2bf]').is_dest_valid?).to eq(true)
    end

    it "ignores invalid ranges" do
      SiteSetting.blacklist_ip_blocks = '2001:abc:de::/48|eviltrout'
      expect(fd('https://[2001:abc:de:01:0:3f0:6a65:c2bf]').is_dest_valid?).to eq(false)
    end

    it "returns true for public ipv6" do
      expect(fd("https://[2001:470:1:3a8::251]").is_dest_valid?).to eq(true)
    end

    it "returns false for private ipv6" do
      expect(fd("https://[fdd7:b450:d4d1:6b44::1]").is_dest_valid?).to eq(false)
    end

    it "returns true for the base uri" do
      SiteSetting.force_hostname = "final-test.example.com"
      expect(fd("https://final-test.example.com/onebox").is_dest_valid?).to eq(true)
    end

    it "returns true for the S3 CDN url" do
      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_cdn_url = "https://s3.example.com"
      expect(fd("https://s3.example.com/some/thing").is_dest_valid?).to eq(true)
    end

    it "returns true for the CDN url" do
      GlobalSetting.stubs(:cdn_url).returns("https://cdn.example.com/discourse")
      expect(fd("https://cdn.example.com/some/asset").is_dest_valid?).to eq(true)
    end

    it 'supports whitelisting via a site setting' do
      SiteSetting.whitelist_internal_hosts = 'private-host.com'
      expect(fd("https://private-host.com/some/url").is_dest_valid?).to eq(true)
    end
  end

  describe "https cache" do
    it 'will cache https lookups' do

      FinalDestination.clear_https_cache!("wikipedia.com")

      stub_request(:head, "http://wikipedia.com/image.png")
        .to_return(status: 302, body: "", headers: { location: 'https://wikipedia.com/image.png' })

      stub_request(:head, "https://wikipedia.com/image.png")

      fd('http://wikipedia.com/image.png').resolve

      stub_request(:head, "https://wikipedia.com/image2.png")

      fd('http://wikipedia.com/image2.png').resolve
    end
  end

  describe "#escape_url" do
    it "correctly escapes url" do
      fragment_url = "https://eviltrout.com/2016/02/25/fixing-android-performance.html#discourse-comments"

      expect(fd(fragment_url).escape_url.to_s).to eq(fragment_url)

      expect(fd("https://eviltrout.com?s=180&#038;d=mm&#038;r=g").escape_url.to_s)
        .to eq("https://eviltrout.com?s=180&d=mm&r=g")

      expect(fd("http://example.com/?a=\11\15").escape_url.to_s).to eq("http://example.com/?a=%09%0D")

      expect(fd("https://ru.wikipedia.org/wiki/%D0%A1%D0%B2%D0%BE%D0%B1%D0%BE").escape_url.to_s)
        .to eq('https://ru.wikipedia.org/wiki/%D0%A1%D0%B2%D0%BE%D0%B1%D0%BE')

      expect(fd('https://ru.wikipedia.org/wiki/Свобо').escape_url.to_s)
        .to eq('https://ru.wikipedia.org/wiki/%D0%A1%D0%B2%D0%BE%D0%B1%D0%BE')
    end
  end

end
