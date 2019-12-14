# frozen_string_literal: true

require 'rails_helper'

describe WildcardDomainChecker do

  describe 'check_domain' do
    context 'valid domain' do
      it 'returns correct domain' do
        result1 = WildcardDomainChecker.check_domain('*.discourse.org', 'anything.is.possible.discourse.org')
        expect(result1[0]).to eq('anything.is.possible.discourse.org')

        result2 = WildcardDomainChecker.check_domain('www.discourse.org', 'www.discourse.org')
        expect(result2[0]).to eq('www.discourse.org')

        result3 = WildcardDomainChecker.check_domain('*', 'hello.discourse.org')
        expect(result3[0]).to eq('hello.discourse.org')
      end
    end

    context 'invalid domain' do
      it "doesn't return the domain" do
        result1 = WildcardDomainChecker.check_domain('*.discourse.org', 'bad-domain.discourse.org.evil.com')
        expect(result1).to eq(nil)

        result2 = WildcardDomainChecker.check_domain('www.discourse.org', 'www.discourse.org.evil.com')
        expect(result2).to eq(nil)

        result3 = WildcardDomainChecker.check_domain('www.discourse.org', 'www.www.discourse.org')
        expect(result3).to eq(nil)

        result4 = WildcardDomainChecker.check_domain('www.*.discourse.org', 'www.www.discourse.org')
        expect(result4).to eq(nil)

        result5 = WildcardDomainChecker.check_domain('www.discourse.org', "www.discourse.org\nwww.discourse.org.evil.com")
        expect(result5).to eq(nil)
      end
    end
  end
end
