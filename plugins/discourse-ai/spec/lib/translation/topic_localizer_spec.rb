# frozen_string_literal: true

describe DiscourseAi::Translation::TopicLocalizer do
  before { enable_current_plugin }

  describe ".localize" do
    fab!(:topic) do
      Fabricate(
        :topic,
        title: "this is a cat topic :)",
        excerpt: "cats are great. how many do you have?",
      )
    end
    let(:translator) { mock }
    let(:translated_title) { "これは猫の話題です :)" }
    let(:translated_excerpt) { "猫は素晴らしいですね。何匹飼っていますか？" }
    let(:fancy_title) { "これは猫の話題です :slight_smile:" }
    let(:target_locale) { "ja" }

    def topic_title_translator_stub(opts)
      mock = instance_double(DiscourseAi::Translation::TopicTitleTranslator)
      allow(DiscourseAi::Translation::TopicTitleTranslator).to receive(:new).with(
        text: opts[:text],
        target_locale: opts[:target_locale],
        topic: opts[:topic] || topic,
      ).and_return(mock)
      allow(mock).to receive(:translate).and_return(opts[:translated])
    end

    def post_raw_translator_stub(opts)
      mock = instance_double(DiscourseAi::Translation::PostRawTranslator)
      allow(DiscourseAi::Translation::PostRawTranslator).to receive(:new).with(
        text: opts[:text],
        target_locale: opts[:target_locale],
        topic: opts[:topic] || topic,
      ).and_return(mock)
      allow(mock).to receive(:translate).and_return(opts[:translated])
    end

    it "returns nil if topic is blank" do
      expect(described_class.localize(nil, "ja")).to eq(nil)
    end

    it "returns nil if target_locale is blank" do
      expect(described_class.localize(topic, nil)).to eq(nil)
      expect(described_class.localize(topic, "")).to eq(nil)
    end

    it "returns nil if target_locale is same as topic locale" do
      topic.locale = "en"

      expect(described_class.localize(topic, "en")).to eq(nil)
    end

    it "translates with topic and locale" do
      topic_title_translator_stub(
        { text: topic.title, target_locale: "ja", translated: translated_title },
      )
      post_raw_translator_stub(
        { text: topic.excerpt, target_locale: "ja", translated: translated_excerpt },
      )

      described_class.localize(topic, "ja")
    end

    it "normalizes dashes to underscores and symbol type for locale" do
      topic_title_translator_stub(
        { text: topic.title, target_locale: "zh_CN", translated: "这是一个猫主题 :)" },
      )
      post_raw_translator_stub(
        { text: topic.excerpt, target_locale: "zh_CN", translated: "这是一个猫主题 :)" },
      )

      described_class.localize(topic, "zh-CN")
    end

    it "finds or creates a TopicLocalization and sets its fields" do
      topic_title_translator_stub(
        { text: topic.title, target_locale: "ja", translated: translated_title },
      )
      post_raw_translator_stub(
        { text: topic.excerpt, target_locale: "ja", translated: translated_excerpt },
      )

      expect {
        res = described_class.localize(topic, target_locale)
        expect(res).to be_a(TopicLocalization)
        expect(res).to have_attributes(
          topic_id: topic.id,
          locale: target_locale,
          title: translated_title,
          excerpt: translated_excerpt,
          fancy_title: fancy_title,
          localizer_user_id: Discourse.system_user.id,
        )
      }.to change { TopicLocalization.count }.by(1)
    end

    it "updates an existing TopicLocalization if present" do
      topic_title_translator_stub(
        { text: topic.title, target_locale: "ja", translated: translated_title },
      )
      post_raw_translator_stub(
        { text: topic.excerpt, target_locale: "ja", translated: translated_excerpt },
      )

      localization =
        Fabricate(
          :topic_localization,
          topic:,
          locale: "ja",
          title: "old title",
          excerpt: "old excerpt",
          fancy_title: "old_fancy_title",
        )
      expect {
        expect(described_class.localize(topic, "ja")).to have_attributes(
          id: localization.id,
          title: translated_title,
          fancy_title: fancy_title,
          excerpt: translated_excerpt,
        )
        expect(localization.reload).to have_attributes(
          title: translated_title,
          fancy_title: fancy_title,
          excerpt: translated_excerpt,
        )
      }.to_not change { TopicLocalization.count }
    end
  end

  describe ".has_relocalize_quota?" do
    fab!(:topic)

    it "returns false if quota is already 2 or more" do
      Discourse.redis.set(described_class.relocalize_key(topic.id, "en"), 2, ex: 10)
      expect(described_class.has_relocalize_quota?(topic.id, "en")).to eq(false)

      Discourse.redis.set(described_class.relocalize_key(topic.id, "en"), 3, ex: 10)
      expect(described_class.has_relocalize_quota?(topic.id, "en")).to eq(false)
    end

    it "returns true if quota is less than 2 and atomically increments quota" do
      Discourse.redis.set(described_class.relocalize_key(topic.id, "en"), 1, ex: 10)

      expect(described_class.has_relocalize_quota?(topic.id, "en")).to eq(true)
      expect(Discourse.redis.get(described_class.relocalize_key(topic.id, "en"))).to eq("2")
    end

    it "atomically increments quota if it was not set before" do
      result = described_class.has_relocalize_quota?(topic.id, "en")

      expect(result).to eq(true)
      expect(Discourse.redis.get(described_class.relocalize_key(topic.id, "en"))).to eq("1")
    end

    it "sets expiry on first increment" do
      described_class.has_relocalize_quota?(topic.id, "en")

      ttl = Discourse.redis.ttl(described_class.relocalize_key(topic.id, "en"))
      expect(ttl).to be > 0
      expect(ttl).to be <= 1.day.to_i
    end
  end
end
