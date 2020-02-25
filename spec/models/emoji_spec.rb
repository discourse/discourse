# frozen_string_literal: true

require 'rails_helper'

describe Emoji do

  it "returns the correct codepoints" do
    expect(Emoji.replacement_code('1f47d').codepoints).to eq([128125])
  end

  it "handles multiple codepoints" do
    expect(Emoji.replacement_code('1f1e9-1f1ea').codepoints).to eq([127465, 127466])
  end

  describe '.load_custom' do
    describe 'when a custom emoji has an invalid upload_id' do
      it 'should return the custom emoji without a URL' do
        CustomEmoji.create!(name: 'test', upload_id: 9999)

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

  describe '.url_for' do
    expected_url = "/images/emoji/twitter/blonde_woman.png?v=#{Emoji::EMOJI_VERSION}"
    expected_toned_url = "/images/emoji/twitter/blonde_woman/6.png?v=#{Emoji::EMOJI_VERSION}"

    it 'should return url with filename' do
      expect(Emoji.url_for("blonde_woman")).to eq(expected_url)
    end

    it 'should return url with skin toned filename' do
      expect(Emoji.url_for("blonde_woman/6")).to eq(expected_toned_url)
    end

    it 'should return url with code' do
      expect(Emoji.url_for(":blonde_woman:")).to eq(expected_url)
    end

    it 'should return url with skin toned code' do
      expect(Emoji.url_for(":blonde_woman:t6:")).to eq(expected_toned_url)
      expect(Emoji.url_for("blonde_woman:t6")).to eq(expected_toned_url)
    end
  end

  describe '.exists?' do
    it 'finds existing emoji' do
      expect(Emoji.exists?(":blonde_woman:")).to be(true)
      expect(Emoji.exists?("blonde_woman")).to be(true)
    end

    it 'finds existing skin toned emoji' do
      expect(Emoji.exists?(":blonde_woman:t1:")).to be(true)
      expect(Emoji.exists?("blonde_woman:t6")).to be(true)
    end

    it 'finds existing custom emoji' do
      CustomEmoji.create!(name: 'test', upload_id: 9999)
      Emoji.clear_cache
      expect(Emoji.exists?(":test:")).to be(true)
      expect(Emoji.exists?("test")).to be(true)
    end

    it 'doesn’t find non-existing emoji' do
      expect(Emoji.exists?(":foo-bar:")).to be(false)
      expect(Emoji.exists?(":blonde_woman:t7:")).to be(false)
      expect(Emoji.exists?("blonde_woman:t0")).to be(false)
      expect(Emoji.exists?("blonde_woman:t")).to be(false)
    end
  end

end
