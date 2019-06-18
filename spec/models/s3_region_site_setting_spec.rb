# frozen_string_literal: true

require 'rails_helper'

describe S3RegionSiteSetting do

  describe 'valid_value?' do
    it 'returns true for a valid S3 region' do
      expect(S3RegionSiteSetting.valid_value?('us-west-1')).to eq(true)
    end

    it 'returns false for an invalid S3 region' do
      expect(S3RegionSiteSetting.valid_value?('the-moon')).to eq(false)
    end
  end

end
