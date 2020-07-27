# frozen_string_literal: true

require 'rails_helper'
require 'oneboxer'

describe Onebox::Engine::AllowlistedGenericOnebox do

  describe ".===" do

    it "matches any domain" do
      expect(described_class === URI('http://foo.bar/resource')).to be(true)
    end

    it "doesn't match an IP address" do
      expect(described_class === URI('http://1.2.3.4/resource')).to be(false)
      expect(described_class === URI('http://1.2.3.4:1234/resource')).to be(false)
    end

  end

  it "allowlists iframes" do
    allowlisted_body = '<html><head><link rel="alternate" type="application/json+oembed" href="https://allowlist.ed/iframes.json" />'
    blocklisted_body = '<html><head><link rel="alternate" type="application/json+oembed" href="https://blocklist.ed/iframes.json" />'

    allowlisted_oembed = {
      type: "rich",
      height: "100",
      html: "<iframe src='https://ifram.es/foo/bar'></iframe>"
    }

    blocklisted_oembed = {
      type: "rich",
      height: "100",
      html: "<iframe src='https://malicious/discourse.org/'></iframe>"
    }

    stub_request(:get, "https://blocklist.ed/iframes").to_return(status: 200, body: blocklisted_body)
    stub_request(:get, "https://blocklist.ed/iframes.json").to_return(status: 200, body: blocklisted_oembed.to_json)

    stub_request(:get, "https://allowlist.ed/iframes").to_return(status: 200, body: allowlisted_body)
    stub_request(:get, "https://allowlist.ed/iframes.json").to_return(status: 200, body: allowlisted_oembed.to_json)

    SiteSetting.allowed_iframes = "discourse.org|https://ifram.es"

    expect(Onebox.preview("https://blocklist.ed/iframes").to_s).to be_empty
    expect(Onebox.preview("https://allowlist.ed/iframes").to_s).to match("iframe src")
  end

end
