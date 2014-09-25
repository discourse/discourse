require 'spec_helper'

describe DigestEmailSiteSetting do
  describe 'valid_value?' do
    it 'returns true for a valid value as an int' do
      DigestEmailSiteSetting.valid_value?(1).should == true
    end

    it 'returns true for a valid value as a string' do
      DigestEmailSiteSetting.valid_value?('1').should == true
    end

    it 'returns false for an invalid value' do
      DigestEmailSiteSetting.valid_value?(1.5).should == false
      DigestEmailSiteSetting.valid_value?('7 dogs').should == false
    end
  end
end
