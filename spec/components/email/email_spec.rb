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

  describe "message_id_rfc_format" do

    it "returns message ID in RFC format" do
      expect(Email.message_id_rfc_format("test@test")).to eq("<test@test>")
    end

    it "returns input if already in RFC format" do
      expect(Email.message_id_rfc_format("<test@test>")).to eq("<test@test>")
    end

  end

  describe "message_id_clean" do

    it "returns message ID if in RFC format" do
      expect(Email.message_id_clean("<test@test>")).to eq("test@test")
    end

    it "returns input if a clean message ID is not in RFC format" do
      message_id = "<" + "@" * 50
      expect(Email.message_id_clean(message_id)).to eq(message_id)
    end

  end

end
