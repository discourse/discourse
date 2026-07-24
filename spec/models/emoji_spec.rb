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

    it "caches the raw upload url, not the CDN-transformed one" do
      upload = Fabricate(:upload, url: "//my-bucket.s3.amazonaws.com/images/my-emoji.png")
      CustomEmoji.create!(name: "my_s3_emoji", upload: upload)

      Emoji.clear_cache
      emoji = Emoji.load_custom.find { |e| e.name == "my_s3_emoji" }

      # The cached object must hold the raw url so that later CDN setting
      # changes are reflected (CDN is applied lazily via #cdn_url).
      expect(emoji.url).to eq(upload.url)
    end
  end

  describe "#cdn_url" do
    it "returns nil when there is no url" do
      expect(Emoji.new.cdn_url).to be_nil
    end

    context "with a configured S3 store and CDN" do
      before do
        setup_s3
        SiteSetting.s3_cdn_url = "https://cdn.example.com"
      end

      def custom_emoji_for(raw_url)
        upload = Fabricate(:upload, url: raw_url)
        CustomEmoji.create!(name: "my_s3_emoji", upload: upload)
        Emoji.clear_cache
        Emoji.load_custom.find { |e| e.name == "my_s3_emoji" }
      end

      it "rewrites a schemaless S3 bucket url to the configured s3_cdn_url" do
        raw_url = "#{SiteSetting.Upload.absolute_base_url}/original/1X/my-emoji.png"
        emoji = custom_emoji_for(raw_url)

        # the cache still holds the raw bucket url...
        expect(emoji.url).to eq(raw_url)
        # ...and the CDN conversion happens lazily on read.
        expect(emoji.cdn_url).to eq("https://cdn.example.com/original/1X/my-emoji.png")
      end

      it "does not leak the bucket subfolder into the rewritten url" do
        SiteSetting.s3_upload_bucket = "s3-upload-bucket/emojis"
        raw_url = "#{SiteSetting.Upload.absolute_base_url}/emojis/original/1X/my-emoji.png"
        emoji = custom_emoji_for(raw_url)

        expect(emoji.cdn_url).to eq("https://cdn.example.com/original/1X/my-emoji.png")
      end
    end
  end

  describe ".unicode_replacements" do
    before { Emoji.clear_cache }

    it "generates correct keys for skin tone and gendered ZWJ sequences" do
      replacements = Emoji.unicode_replacements

      # Case 1: Man Bouncing Ball: Light Skin Tone (RGI)
      # 26f9 (Base) + 1f3fb (Tone) + 200d (ZWJ) + 2642 (Gender) + fe0f (VS16)
      man_bouncing_ball_rgi = [0x26f9, 0x1f3fb, 0x200d, 0x2642, 0xfe0f].pack("U*")
      # Malformed sequence (Old Bug): VS16 incorrectly persisting in the middle
      malformed_key = [0x26f9, 0x1f3fb, 0xfe0f, 0x200d, 0x2642, 0xfe0f].pack("U*")
      expect(replacements.keys).to include(man_bouncing_ball_rgi)
      expect(replacements.keys).not_to include(malformed_key)
      expect(replacements[man_bouncing_ball_rgi]).to eq("man_bouncing_ball:t2")

      # Case 2: Thumbs Up: Light Skin Tone
      thumbs_up = [0x1f44d, 0x1f3fb].pack("U*")
      expect(replacements.keys).to include(thumbs_up)

      # Case 3: Family (Man, Woman, Girl)
      family = [0x1f468, 0x200d, 0x1f469, 0x200d, 0x1f467].pack("U*")
      expect(replacements.keys).to include(family)
    end
  end

  describe ".lookup_unicode" do
    before { Emoji.clear_cache }

    it "returns correct unicode for skin tone and gendered ZWJ sequences" do
      # Case 1: Man Bouncing Ball: Light Skin Tone (RGI)
      expected_rgi = [0x26f9, 0x1f3fb, 0x200d, 0x2642, 0xfe0f].pack("U*")
      expect(Emoji.lookup_unicode("man_bouncing_ball:t2")).to eq(expected_rgi)

      # Case 2: Thumbs Up: Light Skin Tone
      thumbs_up = [0x1f44d, 0x1f3fb].pack("U*")
      expect(Emoji.lookup_unicode("+1:t2")).to eq(thumbs_up)

      # Case 3: Family (Man, Woman, Girl)
      family_skinned = [0x1f468, 0x200d, 0x1f469, 0x200d, 0x1f467].pack("U*")
      expect(Emoji.lookup_unicode("family_man_woman_girl")).to eq(family_skinned)
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

    it "escapes non-emoji text" do
      replaced_str = described_class.codes_to_img(%(This <img src=x onerror="alert('xss')"> :foo:))

      expect(replaced_str).to eq(
        "This &lt;img src=x onerror=&quot;alert(&#39;xss&#39;)&quot;&gt; :foo:",
      )
    end

    it "doesn't double-escape text that already contains HTML entities" do
      replaced_str = described_class.codes_to_img("Sam&rsquo;s :tada: A &amp; B")

      expect(replaced_str).to eq(
        %(Sam&rsquo;s <img src="/images/emoji/twitter/tada.png?v=#{Emoji::EMOJI_VERSION}" title="tada" class="emoji" alt="tada" loading="lazy" width="20" height="20"> A &amp; B),
      )
    end

    it "escapes generated image attribute values" do
      Plugin::CustomEmoji.register("xssxx", %q|" onerror="alert('xss')|)

      replaced_str = described_class.codes_to_img(":xssxx:")

      expect(replaced_str).to eq(
        %(<img src="&quot; onerror=&quot;alert(&#39;xss&#39;)" title="xssxx" class="emoji" alt="xssxx" loading="lazy" width="20" height="20">),
      )
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

  describe ".grouped" do
    before { Emoji.clear_cache }

    it "returns all groups with standard groups present" do
      groups = Emoji.grouped
      expect(groups.keys).to include("flags", "smileys_&_emotion")
    end

    it "preserves standard group order when no groups are pinned" do
      SiteSetting.emoji_picker_pinned_groups = ""
      keys = Emoji.grouped.keys
      expect(keys.index("smileys_&_emotion")).to be < keys.index("flags")
    end

    it "pins a standard group to the top" do
      SiteSetting.emoji_picker_pinned_groups = "flags"
      expect(Emoji.grouped.keys.first).to eq("flags")
    end

    it "pins multiple groups in the configured order" do
      SiteSetting.emoji_picker_pinned_groups = "flags|activities"
      keys = Emoji.grouped.keys
      expect(keys[0]).to eq("flags")
      expect(keys[1]).to eq("activities")
    end

    it "pins a custom group to the top" do
      CustomEmoji.create!(name: "partyblob", upload_id: 9999, group: "reactions")
      Emoji.clear_cache
      SiteSetting.emoji_picker_pinned_groups = "reactions"
      expect(Emoji.grouped.keys.first).to eq("reactions")
    end

    it "silently ignores pinned groups that no longer exist" do
      # Simulate a group that was valid when saved but has since been deleted
      SiteSetting.stubs(:emoji_picker_pinned_groups).returns("nonexistent_group")
      expect { Emoji.grouped }.not_to raise_error
      expect(Emoji.grouped.keys).not_to include("nonexistent_group")
    end

    it "keeps unpinned groups after pinned ones" do
      SiteSetting.emoji_picker_pinned_groups = "flags"
      keys = Emoji.grouped.keys
      flags_index = keys.index("flags")
      smileys_index = keys.index("smileys_&_emotion")
      expect(flags_index).to eq(0)
      expect(smileys_index).to be > flags_index
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
