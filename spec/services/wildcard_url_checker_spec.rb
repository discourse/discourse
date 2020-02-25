# frozen_string_literal: true

require 'rails_helper'

describe WildcardUrlChecker do

  describe 'check_url' do
    context 'valid url' do
      it 'returns true' do
        result1 = described_class.check_url('https://*.discourse.org', 'https://anything.is.possible.discourse.org')
        expect(result1).to eq(true)

        result2 = described_class.check_url('https://www.discourse.org', 'https://www.discourse.org')
        expect(result2).to eq(true)

        result3 = described_class.check_url('*', 'https://hello.discourse.org')
        expect(result3).to eq(true)

        result4 = described_class.check_url('discourse://auth_redirect', 'discourse://auth_redirect')
        expect(result4).to eq(true)

        result5 = described_class.check_url('customprotocol://www.discourse.org', "customprotocol://www.discourse.org")
        expect(result5).to eq(true)
      end
    end

    context 'invalid domain' do
      it "returns false" do
        result1 = described_class.check_url('https://*.discourse.org', 'https://bad-domain.discourse.org.evil.com')
        expect(result1).to eq(false)

        result2 = described_class.check_url('https://www.discourse.org', 'https://www.discourse.org.evil.com')
        expect(result2).to eq(false)

        result3 = described_class.check_url('https://www.discourse.org', 'https://www.www.discourse.org')
        expect(result3).to eq(false)

        result4 = described_class.check_url('https://www.discourse.org', "https://www.discourse.org\nwww.discourse.org.evil.com")
        expect(result4).to eq(false)

        result5 = described_class.check_url('https://', "https://")
        expect(result5).to eq(false)

        result6 = described_class.check_url('invalid$protocol://www.discourse.org', "invalid$protocol://www.discourse.org")
        expect(result6).to eq(false)

        result7 = described_class.check_url('noscheme', "noscheme")
        expect(result7).to eq(false)
      end
    end
  end
end
