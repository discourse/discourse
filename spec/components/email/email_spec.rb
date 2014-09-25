require 'spec_helper'
require 'email'

describe Email do

  describe "is_valid?" do

    it 'treats a good email as valid' do
      Email.is_valid?('sam@sam.com').should == true
    end

    it 'treats a bad email as invalid' do
      Email.is_valid?('sam@sam').should == false
    end

    it 'allows museum tld' do
      Email.is_valid?('sam@nic.museum').should == true
    end

    it 'does not think a word is an email' do
      Email.is_valid?('sam').should == false
    end

  end

  describe "downcase" do

    it 'downcases local and host part' do
      Email.downcase('SAM@GMAIL.COM').should == 'sam@gmail.com'
      Email.downcase('sam@GMAIL.COM').should == 'sam@gmail.com'
    end

    it 'leaves invalid emails untouched' do
      Email.downcase('SAM@GMAILCOM').should == 'SAM@GMAILCOM'
      Email.downcase('samGMAIL.COM').should == 'samGMAIL.COM'
      Email.downcase('sam@GM@AIL.COM').should == 'sam@GM@AIL.COM'
    end

  end

end
