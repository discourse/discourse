require 'spec_helper'
require 'email'

describe Email do

  describe "is_valid?" do

    it 'treats a good email as valid' do
      Email.is_valid?('sam@sam.com').should be_true
    end

    it 'treats a bad email as invalid' do
      Email.is_valid?('sam@sam').should be_false
    end

    it 'allows museum tld' do
      Email.is_valid?('sam@nic.museum').should be_true
    end

    it 'does not think a word is an email' do
      Email.is_valid?('sam').should be_false
    end

  end

  describe "downcase" do

    it 'downcases only the host part' do
      Email.downcase('SAM@GMAIL.COM').should == 'SAM@gmail.com'
      Email.downcase('sam@GMAIL.COM').should_not == 'SAM@gmail.com'
    end

    it 'leaves invalid emails untouched' do
      Email.downcase('SAM@GMAILCOM').should == 'SAM@GMAILCOM'
      Email.downcase('samGMAIL.COM').should == 'samGMAIL.COM'
      Email.downcase('sam@GM@AIL.COM').should == 'sam@GM@AIL.COM'
    end

  end

end
