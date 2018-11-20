require 'rails_helper'

describe Encodings do
  def to_utf8(filename)
    string = File.read("#{Rails.root}/spec/fixtures/encodings/#{filename}").chomp
    Encodings.to_utf8(string)
  end

  context "unicode" do
    let(:expected) { 'Το σύστημα γραφής είναι ένα συμβολικό, οπτικό σύστημα καταγραφής της γλώσσας.' }

    it "correctly encodes UTF-8 as UTF-8" do
      expect(to_utf8('utf-8.txt')).to eq(expected)
    end

    it "correctly encodes UTF-8 with BOM as UTF-8" do
      expect(to_utf8('utf-8-bom.txt')).to eq(expected)
    end

    it "correctly encodes UTF-16LE with BOM as UTF-8" do
      expect(to_utf8('utf-16le.txt')).to eq(expected)
    end

    it "correctly encodes UTF-16BE with BOM as UTF-8" do
      expect(to_utf8('utf-16be.txt')).to eq(expected)
    end
  end

  it "correctly encodes ISO-8859-5 as UTF-8" do
    expect(to_utf8('iso-8859-5.txt')).to eq('Письменность отличается от других существующих или возможных систем символической коммуникации тем, что всегда ассоциируется с некоторым языком и устной речью на этом языке')
  end
end
