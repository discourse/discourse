require 'rails_helper'

describe MailingListModeSiteSetting do
  describe 'valid_value?' do
    it 'returns true for a valid value as an int' do
      expect(DigestEmailSiteSetting.valid_value?(0)).to eq true
    end

    it 'returns false for a valid value as a string' do
      expect(DigestEmailSiteSetting.valid_value?('0')).to eq true
    end

    it 'returns false for an out of range value' do
      expect(DigestEmailSiteSetting.valid_value?(3)).to eq false
    end
  end
end
