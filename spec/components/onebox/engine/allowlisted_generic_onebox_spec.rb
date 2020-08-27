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

end
