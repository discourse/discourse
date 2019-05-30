# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Multisite SiteSettings', type: :multisite do
  before do
    @original_provider = SiteSetting.provider
    SiteSetting.provider = SiteSettings::DbProvider.new(SiteSetting)
  end

  after do
    SiteSetting.provider = @original_provider
  end

  describe '#default_locale' do
    it 'should return the right locale' do
      test_multisite_connection('default') do
        expect(SiteSetting.default_locale).to eq('en_US')
      end

      test_multisite_connection('second') do
        SiteSetting.default_locale = 'zh_TW'

        expect(SiteSetting.default_locale).to eq('zh_TW')
      end

      test_multisite_connection('default') do
        expect(SiteSetting.default_locale).to eq('en_US')

        SiteSetting.default_locale = 'ja'

        expect(SiteSetting.default_locale).to eq('ja')
      end

      test_multisite_connection('second') do
        expect(SiteSetting.default_locale).to eq('zh_TW')
      end
    end
  end
end
