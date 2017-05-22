require 'rails_helper'
require 'final_destination'

describe FinalDestination do

  let(:opts) do
    { # avoid IP lookups in test
      lookup_ip: lambda do |host|
        case host
        when 'eviltrout.com' then '52.84.143.152'
        when 'codinghorror.com' then '91.146.108.148'
        when 'discourse.org' then '104.25.152.10'
        when 'private-host.com' then '192.168.10.1'
        else
          host
        end
      end
    }
  end

  let(:doc_response) do
    { body: "<html>document</html>",
      headers: { "Content-Type" => "text/html" } }
  end

  def redirect_response(from, dest)
    Excon.stub({ method: :head, hostname: from }, { status: 302, headers: { "Location" => dest } })
  end

  describe '.resolve' do

    it "has a ready status code before anything happens" do
      expect(FinalDestination.new('https://eviltrout.com').status).to eq(:ready)
    end

    it "returns nil an invalid url" do
      expect(FinalDestination.new(nil, opts).resolve).to be_nil
      expect(FinalDestination.new('asdf', opts).resolve).to be_nil
    end

    context "without redirects" do
      before do
        Excon.stub({ method: :head, hostname: 'eviltrout.com' }, doc_response)
      end

      it "returns the final url" do
        fd = FinalDestination.new('https://eviltrout.com', opts)
        expect(fd.resolve.to_s).to eq('https://eviltrout.com')
        expect(fd.redirected?).to eq(false)
        expect(fd.status).to eq(:resolved)
      end
    end

    context "with a couple of redirects" do
      before do
        redirect_response("eviltrout.com", "https://codinghorror.com/blog")
        redirect_response("codinghorror.com", "https://discourse.org")
        Excon.stub({ method: :head, hostname: 'discourse.org' }, doc_response)
      end

      it "returns the final url" do
        fd = FinalDestination.new('https://eviltrout.com', opts)
        expect(fd.resolve.to_s).to eq('https://discourse.org')
        expect(fd.redirected?).to eq(true)
        expect(fd.status).to eq(:resolved)
      end
    end

    context "with too many redirects" do
      before do
        redirect_response("eviltrout.com", "https://codinghorror.com/blog")
        redirect_response("codinghorror.com", "https://discourse.org")
        Excon.stub({ method: :head, hostname: 'discourse.org' }, doc_response)
      end

      it "returns the final url" do
        fd = FinalDestination.new('https://eviltrout.com', opts.merge(max_redirects: 1))
        expect(fd.resolve).to be_nil
        expect(fd.redirected?).to eq(true)
        expect(fd.status).to eq(:too_many_redirects)
      end
    end

    context "with a redirect to an internal IP" do
      before do
        redirect_response("eviltrout.com", "https://private-host.com")
        Excon.stub({ method: :head, hostname: 'private-host.com' }, doc_response)
      end

      it "returns the final url" do
        fd = FinalDestination.new('https://eviltrout.com', opts)
        expect(fd.resolve).to be_nil
        expect(fd.redirected?).to eq(true)
        expect(fd.status).to eq(:invalid_address)
      end
    end
  end

  describe '.validate_uri' do
    context "host lookups" do
      it "works for various hosts" do
        expect(FinalDestination.new('https://private-host.com', opts).validate_uri).to eq(false)
        expect(FinalDestination.new('https://eviltrout.com:443', opts).validate_uri).to eq(true)
      end
    end
  end

  describe ".validate_url_format" do
    it "supports http urls" do
      expect(FinalDestination.new('http://eviltrout.com', opts).validate_uri_format).to eq(true)
    end

    it "supports https urls" do
      expect(FinalDestination.new('https://eviltrout.com', opts).validate_uri_format).to eq(true)
    end

    it "doesn't support ftp urls" do
      expect(FinalDestination.new('ftp://eviltrout.com', opts).validate_uri_format).to eq(false)
    end

    it "returns false for schemeless URL" do
      expect(FinalDestination.new('eviltrout.com', opts).validate_uri_format).to eq(false)
    end

    it "returns false for nil URL" do
      expect(FinalDestination.new(nil, opts).validate_uri_format).to eq(false)
    end

    it "returns false for invalid ports" do
      expect(FinalDestination.new('http://eviltrout.com:21', opts).validate_uri_format).to eq(false)
      expect(FinalDestination.new('https://eviltrout.com:8000', opts).validate_uri_format).to eq(false)
    end

    it "returns true for valid ports" do
      expect(FinalDestination.new('http://eviltrout.com:80', opts).validate_uri_format).to eq(true)
      expect(FinalDestination.new('https://eviltrout.com:443',opts).validate_uri_format).to eq(true)
    end
  end

  describe ".is_public" do
    it "returns false for a valid ipv4" do
      expect(FinalDestination.new("https://52.84.143.67", opts).is_public?).to eq(true)
      expect(FinalDestination.new("https://104.25.153.10", opts).is_public?).to eq(true)
    end

    it "returns true for private ipv4" do
      expect(FinalDestination.new("https://127.0.0.1", opts).is_public?).to eq(false)
      expect(FinalDestination.new("https://192.168.1.3", opts).is_public?).to eq(false)
      expect(FinalDestination.new("https://10.0.0.5", opts).is_public?).to eq(false)
      expect(FinalDestination.new("https://172.16.0.1", opts).is_public?).to eq(false)
    end

    it "returns true for public ipv6" do
      expect(FinalDestination.new("https://[2001:470:1:3a8::251]", opts).is_public?).to eq(true)
    end

    it "returns true for private ipv6" do
      expect(FinalDestination.new("https://[fdd7:b450:d4d1:6b44::1]", opts).is_public?).to eq(false)
    end
  end

end
