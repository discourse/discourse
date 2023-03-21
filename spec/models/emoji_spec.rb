# frozen_string_literal: true

RSpec.describe Emoji do
  it "returns the correct codepoints" do
    expect(Emoji.replacement_code("1f47d").codepoints).to eq([128_125])
  end

  it "handles multiple codepoints" do
    expect(Emoji.replacement_code("1f1e9-1f1ea").codepoints).to eq([127_465, 127_466])
  end

  describe ".load_custom" do
    describe "when a custom emoji has an invalid upload_id" do
      it "should return the custom emoji without a URL" do
        CustomEmoji.create!(name: "test", upload_id: 9999)

        emoji = Emoji.load_custom.first

        expect(emoji.name).to eq("test")
        expect(emoji.url).to eq(nil)
      end
    end
  end

  describe ".lookup_unicode" do
    it "should return the emoji" do
      expect(Emoji.lookup_unicode("blonde_man")).to eq("👱")
    end

    it "should return an aliased emoji" do
      expect(Emoji.lookup_unicode("anger_right")).to eq("🗯")
    end

    it "should return a skin toned emoji" do
      expect(Emoji.lookup_unicode("blonde_woman:t6")).to eq("👱🏿‍♀️")
    end
  end

  describe ".url_for" do
    expected_url = "/images/emoji/twitter/blonde_woman.png?v=#{Emoji::EMOJI_VERSION}"
    expected_toned_url = "/images/emoji/twitter/blonde_woman/6.png?v=#{Emoji::EMOJI_VERSION}"

    it "should return url with filename" do
      expect(Emoji.url_for("blonde_woman")).to eq(expected_url)
    end

    it "should return url with skin toned filename" do
      expect(Emoji.url_for("blonde_woman/6")).to eq(expected_toned_url)
    end

    it "should return url with code" do
      expect(Emoji.url_for(":blonde_woman:")).to eq(expected_url)
    end

    it "should return url with skin toned code" do
      expect(Emoji.url_for(":blonde_woman:t6:")).to eq(expected_toned_url)
      expect(Emoji.url_for("blonde_woman:t6")).to eq(expected_toned_url)
    end
  end

  describe ".exists?" do
    it "finds existing emoji" do
      expect(Emoji.exists?(":blonde_woman:")).to be(true)
      expect(Emoji.exists?("blonde_woman")).to be(true)
    end

    it "finds existing skin toned emoji" do
      expect(Emoji.exists?(":blonde_woman:t1:")).to be(true)
      expect(Emoji.exists?("blonde_woman:t6")).to be(true)
    end

    it "finds existing custom emoji" do
      CustomEmoji.create!(name: "test", upload_id: 9999)
      Emoji.clear_cache
      expect(Emoji.exists?(":test:")).to be(true)
      expect(Emoji.exists?("test")).to be(true)
    end

    it "finds a custom emoji with a name with :t1 in the middle" do
      CustomEmoji.create!(name: "test:t1:foo", upload_id: 9999)
      Emoji.clear_cache
      expect(Emoji.exists?(":test:t1:foo:")).to be(true)
      expect(Emoji.exists?("test:t1:foo")).to be(true)
    end

    it "doesn’t find non-existing emoji" do
      expect(Emoji.exists?(":foo-bar:")).to be(false)
      expect(Emoji.exists?(":blonde_woman:t7:")).to be(false)
      expect(Emoji.exists?("blonde_woman:t0")).to be(false)
      expect(Emoji.exists?("blonde_woman:t")).to be(false)
    end
  end

  describe "version updates" do
    it "should correct cache when global emojis cache is stale" do
      Emoji.global_emoji_cache["blonde_man"] = ["invalid", Emoji.new]

      emoji = Emoji[":blonde_man:t3"]

      expect(emoji.name).to eq("blonde_man")
      expect(emoji.tonable).to eq(true)
    end

    it "should correct cache when site emojis cache is stale" do
      CustomEmoji.create!(name: "test123", upload_id: 9999)
      Emoji.clear_cache

      Emoji.site_emoji_cache["test123"] = ["invalid", Emoji.new]

      emoji = Emoji[":test123:"]

      expect(emoji.name).to eq("test123")
      expect(emoji.tonable).to be_falsey

      Emoji.clear_cache
    end
  end

  describe ".codes_to_img" do
    before { Plugin::CustomEmoji.clear_cache }
    after { Plugin::CustomEmoji.clear_cache }

    it "replaces emoji codes by images" do
      Plugin::CustomEmoji.register("xxxxxx", "/public/xxxxxx.png")

      str = "This is a good day :xxxxxx: :woman: :man:t4:"
      replaced_str = described_class.codes_to_img(str)

      expect(replaced_str).to eq(
        "This is a good day <img src=\"/public/xxxxxx.png\" title=\"xxxxxx\" class=\"emoji\" alt=\"xxxxxx\" loading=\"lazy\" width=\"20\" height=\"20\"> <img src=\"/images/emoji/twitter/woman.png?v=#{Emoji::EMOJI_VERSION}\" title=\"woman\" class=\"emoji\" alt=\"woman\" loading=\"lazy\" width=\"20\" height=\"20\"> <img src=\"/images/emoji/twitter/man/4.png?v=#{Emoji::EMOJI_VERSION}\" title=\"man:t4\" class=\"emoji\" alt=\"man:t4\" loading=\"lazy\" width=\"20\" height=\"20\">",
      )
    end

    it "doesn't replace if code doesn't exist" do
      str = "This is a good day :woman: :foo: :bar:t4: :man:t8:"
      replaced_str = described_class.codes_to_img(str)

      expect(replaced_str).to eq(
        "This is a good day <img src=\"/images/emoji/twitter/woman.png?v=#{Emoji::EMOJI_VERSION}\" title=\"woman\" class=\"emoji\" alt=\"woman\" loading=\"lazy\" width=\"20\" height=\"20\"> :foo: :bar:t4: :man:t8:",
      )
    end
  end

  describe ".groups" do
    it "returns an optimized emoji name -> group name datastructure" do
      expect(Emoji.groups["scotland"]).to eq("flags")
    end
  end

  describe ".load_standard" do
    it "removes nil emojis" do
      expect(Emoji.load_standard.any? { |element| element.nil? }).to be false
    end
  end

  describe "#create_from_db_item" do
    it "sets the group of the emoji" do
      emoji = Emoji.create_from_db_item("name" => "scotland")
      expect(emoji.group).to eq("flags")
    end

    it "sets the group of the emoji" do
      emoji = Emoji.create_from_db_item("name" => "scotland")
      expect(emoji.group).to eq("flags")
    end

    it "doesn’t create emoji when group is unknown" do
      emoji = Emoji.create_from_db_item("name" => "white_hair")
      expect(emoji).to be_nil
    end
  end
end
