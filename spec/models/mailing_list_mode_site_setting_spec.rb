# frozen_string_literal: true

require 'rails_helper'

describe MailingListModeSiteSetting do
  describe 'valid_value?' do
    it 'returns true for a valid value as an int' do
      expect(MailingListModeSiteSetting.valid_value?(1)).to eq(true)
    end

    it 'returns true for a valid value as a string' do
      expect(MailingListModeSiteSetting.valid_value?('1')).to eq(true)
    end

    it 'returns false for an out of range value' do
      [0, 3].each do |value|
        expect(MailingListModeSiteSetting.valid_value?(value)).to eq(false)
      end
    end
  end
end
