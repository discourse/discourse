require 'rails_helper'

describe DigestEmailSiteSetting do
  describe 'valid_value?' do
    it 'returns true for a valid value as an int' do
      expect(DigestEmailSiteSetting.valid_value?(1440)).to eq true
    end

    it 'returns true for a valid value as a string' do
      expect(DigestEmailSiteSetting.valid_value?('1440')).to eq true
    end

    it 'returns false for an invalid value' do
      expect(DigestEmailSiteSetting.valid_value?('7 dogs')).to eq false
    end
  end
end
