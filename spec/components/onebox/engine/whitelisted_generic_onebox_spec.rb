# frozen_string_literal: true

require 'rails_helper'
require 'oneboxer'

describe Onebox::Engine::WhitelistedGenericOnebox do

  describe ".===" do

    it "matches any domain" do
      expect(described_class === URI('http://foo.bar/resource')).to be(true)
    end

    it "doesn't match an IP address" do
      expect(described_class === URI('http://1.2.3.4/resource')).to be(false)
      expect(described_class === URI('http://1.2.3.4:1234/resource')).to be(false)
    end

  end

  it "whitelists iframes" do
    whitelisted_body = '<html><head><link rel="alternate" type="application/json+oembed" href="https://whitelist.ed/iframes.json" />'
    blacklisted_body = '<html><head><link rel="alternate" type="application/json+oembed" href="https://blacklist.ed/iframes.json" />'

    whitelisted_oembed = {
      type: "rich",
      height: "100",
      html: "<iframe src='https://ifram.es/foo/bar'></iframe>"
    }

    blacklisted_oembed = {
      type: "rich",
      height: "100",
      html: "<iframe src='https://malicious/discourse.org/'></iframe>"
    }

    stub_request(:get, "https://blacklist.ed/iframes").to_return(status: 200, body: blacklisted_body)
    stub_request(:get, "https://blacklist.ed/iframes.json").to_return(status: 200, body: blacklisted_oembed.to_json)

    stub_request(:get, "https://whitelist.ed/iframes").to_return(status: 200, body: whitelisted_body)
    stub_request(:get, "https://whitelist.ed/iframes.json").to_return(status: 200, body: whitelisted_oembed.to_json)

    SiteSetting.allowed_iframes = "discourse.org|https://ifram.es"

    expect(Onebox.preview("https://blacklist.ed/iframes").to_s).to be_empty
    expect(Onebox.preview("https://whitelist.ed/iframes").to_s).to match("iframe src")
  end

end
