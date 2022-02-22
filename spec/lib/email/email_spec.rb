# frozen_string_literal: true

require 'rails_helper'
require 'email'

describe Email do

  describe "is_valid?" do

    it 'treats a nil as invalid' do
      expect(Email.is_valid?(nil)).to eq(false)
    end

    it 'treats a good email as valid' do
      expect(Email.is_valid?('sam@sam.com')).to eq(true)
    end

    it 'treats a bad email as invalid' do
      expect(Email.is_valid?('sam@sam')).to eq(false)
    end

    it 'allows museum tld' do
      expect(Email.is_valid?('sam@nic.museum')).to eq(true)
    end

    it 'does not think a word is an email' do
      expect(Email.is_valid?('sam')).to eq(false)
    end

  end

  describe "downcase" do

    it 'downcases local and host part' do
      expect(Email.downcase('SAM@GMAIL.COM')).to eq('sam@gmail.com')
      expect(Email.downcase('sam@GMAIL.COM')).to eq('sam@gmail.com')
    end

    it 'leaves invalid emails untouched' do
      expect(Email.downcase('SAM@GMAILCOM')).to eq('SAM@GMAILCOM')
      expect(Email.downcase('samGMAIL.COM')).to eq('samGMAIL.COM')
      expect(Email.downcase('sam@GM@AIL.COM')).to eq('sam@GM@AIL.COM')
    end

  end

  describe "obfuscate" do

    it 'correctly obfuscates emails' do
      expect(Email.obfuscate('a@b.com')).to eq('*@*.com')
      expect(Email.obfuscate('test@test.co.uk')).to eq('t***@t***.**.uk')
      expect(Email.obfuscate('simple@example.com')).to eq('s****e@e*****e.com')
      expect(Email.obfuscate('very.common@example.com')).to eq('v*********n@e*****e.com')
      expect(Email.obfuscate('disposable.style.email.with+symbol@example.com')).to eq('d********************************l@e*****e.com')
      expect(Email.obfuscate('other.email-with-hyphen@example.com')).to eq('o*********************n@e*****e.com')
      expect(Email.obfuscate('fully-qualified-domain@example.com')).to eq('f********************n@e*****e.com')
      expect(Email.obfuscate('user.name+tag+sorting@example.com')).to eq('u*******************g@e*****e.com')
      expect(Email.obfuscate('x@example.com')).to eq('*@e*****e.com')
      expect(Email.obfuscate('example-indeed@strange-example.com')).to eq('e************d@s*************e.com')
      expect(Email.obfuscate('example@s.example')).to eq('e*****e@*.example')
      expect(Email.obfuscate('mailhost!username@example.org')).to eq('m***************e@e*****e.org')
      expect(Email.obfuscate('user%example.com@example.org')).to eq('u**************m@e*****e.org')
      expect(Email.obfuscate('user-@example.org')).to eq('u***-@e*****e.org')
    end

  end
end
