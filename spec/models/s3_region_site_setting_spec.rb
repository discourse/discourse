require 'spec_helper'

describe S3RegionSiteSetting do

  describe 'valid_value?' do
    it 'returns true for a valid S3 region' do
      expect(S3RegionSiteSetting.valid_value?('us-west-1')).to eq(true)
    end

    it 'returns false for an invalid S3 region' do
      expect(S3RegionSiteSetting.valid_value?('the-moon')).to eq(false)
    end
  end

  describe 'values' do
    it 'returns all the S3 regions' do
      expect(S3RegionSiteSetting.values.map {|x| x[:value]}.sort).to eq(['us-east-1', 'us-west-1', 'us-west-2', 'us-gov-west-1', 'eu-west-1', 'eu-central-1', 'ap-southeast-1', 'ap-southeast-2', 'ap-northeast-1', 'sa-east-1'].sort)
    end
  end

end
