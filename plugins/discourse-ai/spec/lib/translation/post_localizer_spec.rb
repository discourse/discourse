# frozen_string_literal: true

describe DiscourseAi::Translation::PostLocalizer do
  before { enable_current_plugin }

  describe ".localize" do
    fab!(:post) { Fabricate(:post, raw: "Hello world", version: 1) }
    let(:translator) { mock }
    let(:translated_raw) { "こんにちは世界" }
    let(:cooked) { "<p>こんにちは世界</p>" }
    let(:target_locale) { "ja" }

    def post_raw_translator_stub(opts)
      mock = instance_double(DiscourseAi::Translation::PostRawTranslator)
      allow(DiscourseAi::Translation::PostRawTranslator).to receive(:new).with(
        text: opts[:text],
        target_locale: opts[:target_locale],
        post: opts[:post] || post,
      ).and_return(mock)
      allow(mock).to receive(:translate).and_return(opts[:translated])
    end

    it "returns nil if post does not exist" do
      expect(described_class.localize(nil, "ja")).to eq(nil)
    end

    it "returns nil if target_locale is blank" do
      expect(described_class.localize(post, nil)).to eq(nil)
      expect(described_class.localize(post, "")).to eq(nil)
    end

    it "returns nil if target_locale is same as post locale" do
      post.locale = "en"

      expect(described_class.localize(post, "en")).to eq(nil)
    end

    it "returns nil if post raw is blank" do
      post.raw = ""

      expect(described_class.localize(post, "ja")).to eq(nil)
    end

    it "returns nil if post raw is too long" do
      SiteSetting.ai_translation_max_post_length = 10
      post.raw = "This is a very long post that exceeds the limit."

      expect(described_class.localize(post, "ja")).to eq(nil)
    end

    it "translates with post and locale" do
      post_raw_translator_stub({ text: post.raw, target_locale: "ja", translated: translated_raw })

      described_class.localize(post, "ja")
    end

    it "normalizes dashes to underscores and symbol type for locale" do
      post_raw_translator_stub({ text: post.raw, target_locale: "zh_CN", translated: "你好，世界" })

      described_class.localize(post, "zh-CN")
    end

    it "finds or creates a PostLocalization and sets its fields" do
      post_raw_translator_stub({ text: post.raw, target_locale: "ja", translated: translated_raw })
      expect {
        res = described_class.localize(post, target_locale)
        expect(res).to be_a(PostLocalization)
        expect(res).to have_attributes(
          post_id: post.id,
          locale: target_locale,
          raw: translated_raw,
          cooked: cooked,
          post_version: post.version,
          localizer_user_id: Discourse.system_user.id,
        )
      }.to change { PostLocalization.count }.by(1)
    end

    it "updates an existing PostLocalization if present" do
      post_raw_translator_stub({ text: post.raw, target_locale: "ja", translated: translated_raw })
      localization =
        Fabricate(:post_localization, post: post, locale: "ja", raw: "old", cooked: "old_cooked")
      expect {
        out = described_class.localize(post, "ja")
        expect(out.id).to eq(localization.id)
        expect(out.raw).to eq(translated_raw)
        expect(out.cooked).to eq(cooked)
      }.to_not change { PostLocalization.count }
    end

    context "with oneboxes" do
      fab!(:topic_to_onebox) { Fabricate(:topic) }
      let(:onebox_url) { topic_to_onebox.url }
      let(:post) { Fabricate(:post, raw: onebox_url) }
      let(:translated_raw) { onebox_url }
      let(:onebox_html) do
        "<aside class=\"onebox\"><a href=\"#{onebox_url}\">#{topic_to_onebox.title}</a></aside>"
      end

      before { Oneboxer.stubs(:onebox).with(onebox_url, anything).returns(onebox_html) }

      it "creates oneboxes in the cooked HTML" do
        post_raw_translator_stub(
          { text: post.raw, target_locale: "ja", translated: translated_raw },
        )
        localization = described_class.localize(post, "ja")
        expect(localization.cooked).to include(onebox_html)
      end
    end
  end

  describe ".has_relocalize_quota?" do
    fab!(:post)

    it "returns false if quota is already 2 or more" do
      Discourse.redis.set(described_class.relocalize_key(post, "en"), 2, ex: 10)
      expect(described_class.has_relocalize_quota?(post, "en")).to eq(false)

      Discourse.redis.set(described_class.relocalize_key(post, "en"), 3, ex: 10)
      expect(described_class.has_relocalize_quota?(post, "en")).to eq(false)
    end

    it "returns true if quota is less than 2 and increments quota" do
      Discourse.redis.set(described_class.relocalize_key(post, "en"), 1, ex: 10)

      expect(described_class.has_relocalize_quota?(post, "en")).to eq(true)
    end

    it "does not increment quota if skip_incr is true" do
      Discourse.redis.set(described_class.relocalize_key(post, "en"), 1, ex: 10)

      described_class.has_relocalize_quota?(post, "en", skip_incr: true)
      expect(Discourse.redis.get(described_class.relocalize_key(post, "en"))).to eq("1")
    end

    it "increments quota if it was not set before" do
      described_class.has_relocalize_quota?(post, "en")

      expect(Discourse.redis.get(described_class.relocalize_key(post, "en"))).to eq("1")
    end
  end
end
