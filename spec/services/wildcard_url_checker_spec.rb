# frozen_string_literal: true

require 'rails_helper'

describe WildcardUrlChecker do

  describe 'check_url' do
    context 'valid url' do
      it 'returns correct domain' do
        result1 = described_class.check_url('https://*.discourse.org', 'https://anything.is.possible.discourse.org')
        expect(result1[0]).to eq('https://anything.is.possible.discourse.org')

        result2 = described_class.check_url('https://www.discourse.org', 'https://www.discourse.org')
        expect(result2[0]).to eq('https://www.discourse.org')

        result3 = described_class.check_url('*', 'https://hello.discourse.org')
        expect(result3[0]).to eq('https://hello.discourse.org')

        result4 = described_class.check_url('discourse://auth_redirect', 'discourse://auth_redirect')
        expect(result4[0]).to eq('discourse://auth_redirect')
      end
    end

    context 'invalid domain' do
      it "doesn't return the domain" do
        result1 = described_class.check_url('https://*.discourse.org', 'https://bad-domain.discourse.org.evil.com')
        expect(result1).to eq(nil)

        result2 = described_class.check_url('https://www.discourse.org', 'https://www.discourse.org.evil.com')
        expect(result2).to eq(nil)

        result3 = described_class.check_url('https://www.discourse.org', 'https://www.www.discourse.org')
        expect(result3).to eq(nil)

        result4 = described_class.check_url('https://www.discourse.org', "https://www.discourse.org\nwww.discourse.org.evil.com")
        expect(result4).to eq(nil)

        result5 = described_class.check_url('ttps://www.discourse.org', "ttps://www.discourse.org")
        expect(result5).to eq(nil)

        result6 = described_class.check_url('https://', "https://")
        expect(result6).to eq(nil)
      end
    end
  end
end
