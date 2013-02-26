require 'spec_helper'
require 'email'

describe Email do


  it 'should treat a good email as valid' do
    Email.is_valid?('sam@sam.com').should be_true
  end

  it 'should treat a bad email as invalid' do
    Email.is_valid?('sam@sam').should be_false
  end

  it 'should allow museum tld' do
    Email.is_valid?('sam@nic.museum').should be_true
  end

  it 'should not think a word is an email' do
    Email.is_valid?('sam').should be_false
  end
end
