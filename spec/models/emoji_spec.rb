require 'rails_helper'

describe Emoji do

  it "returns the correct codepoints" do
    expect(Emoji.replacement_code('1f47d').codepoints).to eq([128125])
  end

  it "handles multiple codepoints" do
    expect(Emoji.replacement_code('1f1e9-1f1ea').codepoints).to eq([127465, 127466])
  end

  it "returns nil for weird cases" do
    expect(Emoji.replacement_code('32')).to be_nil
    expect(Emoji.replacement_code('robin')).to be_nil
  end

  describe '.load_custom' do
    describe 'when a custom emoji has an invalid upload_id' do
      it 'should return the custom emoji without a URL' do
        CustomEmoji.create!(name: 'test', upload_id: -1)

        emoji = Emoji.load_custom.first

        expect(emoji.name).to eq('test')
        expect(emoji.url).to eq(nil)
      end
    end
  end

  describe '.lookup_unicode' do
    it 'should return the emoji' do
      expect(Emoji.lookup_unicode("blonde_man")).to eq("👱")
    end

    it 'should return an aliased emoji' do
      expect(Emoji.lookup_unicode("anger_right")).to eq("🗯")
    end

    it 'should return a skin toned emoji' do
      expect(Emoji.lookup_unicode("blonde_woman:t6")).to eq("👱🏿‍♀️")
    end
  end

end
