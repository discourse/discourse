# frozen_string_literal: true

RSpec.describe Emoji do
  describe ".replacement_code" do
    it "returns correct codepoints" do
      expect(Emoji.replacement_code("1f47d").codepoints).to eq([128_125])
      expect(Emoji.replacement_code("1f1e9-1f1ea").codepoints).to eq([127_465, 127_466])
    end
  end

  describe ".load_custom" do
    it "returns custom emoji without URL when upload_id is invalid" do
      CustomEmoji.create!(name: "test", upload_id: 9999)
      emoji = Emoji.load_custom.first
      expect(emoji.name).to eq("test")
      expect(emoji.url).to be_nil
    end
  end

  describe ".lookup_unicode" do
    it "returns unicode for emoji, aliases, and skin tones" do
      expect(Emoji.lookup_unicode("trade_mark")).to eq("™")
      expect(Emoji.lookup_unicode("blonde_man")).to eq("👱‍♂️")
      expect(Emoji.lookup_unicode("anger_right")).to eq("🗯")
      expect(Emoji.lookup_unicode("blonde_woman:t6")).to eq("👱🏿‍♀️")
    end

    it "respects emoji deny list" do
      SiteSetting.emoji_deny_list = "peach"
      Emoji.clear_cache
      expect(Emoji.lookup_unicode("peach")).not_to eq("🍑")
    end
  end

  describe ".url_for" do
    it "returns correct url for all input formats" do
      url = "/images/emoji/twitter/blonde_woman.png?v=#{Emoji::EMOJI_VERSION}"
      toned_url = "/images/emoji/twitter/blonde_woman/6.png?v=#{Emoji::EMOJI_VERSION}"

      expect(Emoji.url_for("blonde_woman")).to eq(url)
      expect(Emoji.url_for(":blonde_woman:")).to eq(url)
      expect(Emoji.url_for("blonde_woman:t6")).to eq(toned_url)
      expect(Emoji.url_for(":blonde_woman:t6:")).to eq(toned_url)
    end
  end

  describe ".resolve_alias" do
    it "resolves aliases to canonical names" do
      expect(Emoji.resolve_alias("xray")).to eq("x_ray")
      expect(Emoji.resolve_alias("blonde_woman")).to eq("blonde_woman")
    end
  end

  describe "emoji lookup" do
    it "finds emoji by name" do
      expect(Emoji["blonde_woman"].name).to eq("blonde_woman")
      expect(Emoji[":blonde_woman:"].name).to eq("blonde_woman")
      expect(Emoji.exists?("blonde_woman")).to be(true)
      expect(Emoji.exists?(":blonde_woman:")).to be(true)
    end

    it "finds emoji by alias" do
      expect(Emoji["xray"].name).to eq("x_ray")
      expect(Emoji[":xray:"].name).to eq("x_ray")
      expect(Emoji.exists?("xray")).to be(true)
      expect(Emoji.exists?(":xray:")).to be(true)
    end

    it "finds tonable emoji with skin tone" do
      expect(Emoji["blonde_woman:t6"].name).to eq("blonde_woman")
      expect(Emoji[":blonde_woman:t6:"].name).to eq("blonde_woman")
      expect(Emoji.exists?("blonde_woman:t6")).to be(true)
      expect(Emoji.exists?(":blonde_woman:t1:")).to be(true)
    end

    it "finds tonable emoji by alias with skin tone" do
      expect(Emoji["basketball_man:t4"].name).to eq("man_bouncing_ball")
      expect(Emoji[":basketball_man:t4:"].name).to eq("man_bouncing_ball")
      expect(Emoji.exists?("basketball_man:t4")).to be(true)
      expect(Emoji.exists?(":basketball_man:t4:")).to be(true)
    end

    it "finds custom emoji" do
      CustomEmoji.create!(name: "test", upload_id: 9999)
      Emoji.clear_cache
      expect(Emoji.exists?("test")).to be(true)
      expect(Emoji.exists?(":test:")).to be(true)
    end

    it "finds custom emoji with skin tone pattern in name" do
      CustomEmoji.create!(name: "test:t1:foo", upload_id: 9999)
      Emoji.clear_cache
      expect(Emoji.exists?("test:t1:foo")).to be(true)
      expect(Emoji.exists?(":test:t1:foo:")).to be(true)
    end

    it "returns nil/false for non-existing emoji" do
      expect(Emoji["foo_bar_baz"]).to be_nil
      expect(Emoji[":foo_bar_baz:"]).to be_nil
      expect(Emoji.exists?(":foo-bar:")).to be(false)
    end

    it "returns nil/false for invalid skin tones" do
      expect(Emoji["apple:t4"]).to be_nil
      expect(Emoji.exists?(":blonde_woman:t7:")).to be(false)
      expect(Emoji.exists?("blonde_woman:t0")).to be(false)
      expect(Emoji.exists?("blonde_woman:t")).to be(false)
    end
  end

  describe ".codes_to_img" do
    before { Plugin::CustomEmoji.clear_cache }
    after { Plugin::CustomEmoji.clear_cache }

    it "replaces emoji codes by images" do
      Plugin::CustomEmoji.register("xxxxxx", "/public/xxxxxx.png")
      replaced_str = described_class.codes_to_img("This is a good day :xxxxxx: :woman: :man:t4:")
      expect(replaced_str).to eq(<<~HTML.chomp)
        This is a good day <img src="/public/xxxxxx.png" title="xxxxxx" class="emoji" alt="xxxxxx" loading="lazy" width="20" height="20"> <img src="/images/emoji/twitter/woman.png?v=#{Emoji::EMOJI_VERSION}" title="woman" class="emoji" alt="woman" loading="lazy" width="20" height="20"> <img src="/images/emoji/twitter/man/4.png?v=#{Emoji::EMOJI_VERSION}" title="man:t4" class="emoji" alt="man:t4" loading="lazy" width="20" height="20">
      HTML
    end

    it "doesn't replace non-existing codes" do
      replaced_str =
        described_class.codes_to_img("This is a good day :woman: :foo: :bar:t4: :man:t8:")
      expect(replaced_str).to eq(<<~HTML.chomp)
        This is a good day <img src="/images/emoji/twitter/woman.png?v=#{Emoji::EMOJI_VERSION}" title="woman" class="emoji" alt="woman" loading="lazy" width="20" height="20"> :foo: :bar:t4: :man:t8:
      HTML
    end
  end

  describe ".groups" do
    it "returns emoji name to group name mapping" do
      expect(Emoji.groups["scotland"]).to eq("flags")
    end
  end

  describe ".load_standard" do
    it "removes nil emojis" do
      expect(Emoji.load_standard.any?(&:nil?)).to be(false)
    end
  end

  describe "#create_from_db_item" do
    it "creates emoji with group when known" do
      emoji = Emoji.create_from_db_item("name" => "scotland")
      expect(emoji.group).to eq("flags")
    end

    it "returns nil when group is unknown" do
      expect(Emoji.create_from_db_item("name" => "white_hair")).to be_nil
    end
  end
end
