require 'rails_helper'
require 'final_destination'

describe FinalDestination do

  let(:opts) do
    {
      ignore_redirects: ['https://ignore-me.com'],

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
        else
          as_ip = IPAddr.new(host) rescue nil
          raise "couldn't lookup #{host}" if as_ip.nil?
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

  describe '.resolve' do

    it "has a ready status code before anything happens" do
      expect(fd('https://eviltrout.com').status).to eq(:ready)
    end

    it "returns nil an invalid url" do
      expect(fd(nil).resolve).to be_nil
      expect(fd('asdf').resolve).to be_nil
    end

    context "without redirects" do
      before do
        stub_request(:head, "https://eviltrout.com").to_return(doc_response)
      end

      it "escapes url" do
        url = 'https://eviltrout.com?s=180&#038;d=mm&#038;r=g'
        escaped_url = URI.escape(url)
        stub_request(:head, escaped_url).to_return(doc_response)

        expect(fd(url).resolve.to_s).to eq(escaped_url)
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

    context "HEAD not supported" do
      before do
        stub_request(:get, 'https://eviltrout.com').to_return(
          status: 301,
          headers: {
            "Location" => 'https://discourse.org',
            'Set-Cookie' => 'evil=trout'
          }
        )
        stub_request(:head, 'https://discourse.org').to_return(status: 200)
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

end
