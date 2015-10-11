require 'rails_helper'

describe LocaleSiteSetting do

  describe 'valid_value?' do
    it 'returns true for a locale that we have translations for' do
      expect(LocaleSiteSetting.valid_value?('en')).to eq(true)
    end

    it 'returns false for a locale that we do not have translations for' do
      expect(LocaleSiteSetting.valid_value?('swedish-chef')).to eq(false)
    end
  end

  describe 'values' do
    it 'returns all the locales that we have translations for' do
      expect(LocaleSiteSetting.values.map {|x| x[:value]}.sort).to eq(Dir.glob( File.join(Rails.root, 'config', 'locales', 'client.*.yml') ).map {|x| x.split('.')[-2]}.sort)
    end
  end

end
