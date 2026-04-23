# frozen_string_literal: true

describe DiscourseAi::Translation::TopicCandidates do
  before { SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|") }

  describe ".get" do
    it "does not return bot topics" do
      topic = Fabricate(:topic, user: Discourse.system_user)
      SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

      expect(DiscourseAi::Translation::TopicCandidates.get).not_to include(topic)
    end

    describe "SiteSetting.ai_translation_include_bot_content" do
      it "includes bot topics when enabled" do
        SiteSetting.ai_translation_include_bot_content = true
        bot_topic = Fabricate(:topic, user: Discourse.system_user)
        regular_topic = Fabricate(:topic)
        SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

        topics = DiscourseAi::Translation::TopicCandidates.get
        expect(topics).to include(bot_topic)
        expect(topics).to include(regular_topic)
      end
    end

    it "does not return topics older than ai_translation_backfill_max_age_days" do
      topic =
        Fabricate(
          :topic,
          created_at: SiteSetting.ai_translation_backfill_max_age_days.days.ago - 1.day,
        )
      SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

      expect(DiscourseAi::Translation::TopicCandidates.get).not_to include(topic)
    end

    it "returns banner topics even when older than max_age_days" do
      banner_topic =
        Fabricate(
          :topic,
          archetype: Archetype.banner,
          created_at: SiteSetting.ai_translation_backfill_max_age_days.days.ago - 30.days,
        )

      expect(DiscourseAi::Translation::TopicCandidates.get).to include(banner_topic)
    end

    it "returns banner topics even when no target categories are set" do
      SiteSetting.ai_translation_target_categories = ""
      SiteSetting.ai_translation_personal_messages = "none"

      banner_topic = Fabricate(:topic, archetype: Archetype.banner)

      expect(DiscourseAi::Translation::TopicCandidates.get).to include(banner_topic)
    end

    it "does not return deleted banner topics" do
      banner_topic = Fabricate(:topic, archetype: Archetype.banner, deleted_at: Time.now)

      expect(DiscourseAi::Translation::TopicCandidates.get).not_to include(banner_topic)
    end

    it "does not return deleted topics" do
      topic = Fabricate(:topic, deleted_at: Time.now)
      SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

      expect(DiscourseAi::Translation::TopicCandidates.get).not_to include(topic)
    end

    describe "category and PM filtering" do
      fab!(:target_category, :category)
      fab!(:non_target_category, :category)
      fab!(:pm, :private_message_topic)
      fab!(:group_pm) { Fabricate(:private_message_topic, allowed_groups: [Fabricate(:group)]) }
      fab!(:target_topic) { Fabricate(:topic, category: target_category) }
      fab!(:non_target_topic) { Fabricate(:topic, category: non_target_category) }

      it "only includes topics from target categories when target_categories is set" do
        SiteSetting.ai_translation_target_categories = target_category.id.to_s

        topics = DiscourseAi::Translation::TopicCandidates.get
        expect(topics).to include(target_topic)
        expect(topics).not_to include(non_target_topic)
      end

      it "returns no regular topics when target_categories is empty" do
        SiteSetting.ai_translation_target_categories = ""
        SiteSetting.ai_translation_personal_messages = "none"

        topics = DiscourseAi::Translation::TopicCandidates.get
        expect(topics).not_to include(target_topic)
        expect(topics).not_to include(non_target_topic)
        expect(topics).not_to include(pm)
        expect(topics).not_to include(group_pm)
      end

      it "excludes all PMs when pm_translation_scope is none" do
        SiteSetting.ai_translation_target_categories = target_category.id.to_s
        SiteSetting.ai_translation_personal_messages = "none"

        topics = DiscourseAi::Translation::TopicCandidates.get
        expect(topics).to include(target_topic)
        expect(topics).not_to include(pm)
        expect(topics).not_to include(group_pm)
      end

      it "includes group PMs but not personal PMs when pm_translation_scope is group" do
        SiteSetting.ai_translation_target_categories = target_category.id.to_s
        SiteSetting.ai_translation_personal_messages = "group"

        topics = DiscourseAi::Translation::TopicCandidates.get
        expect(topics).to include(target_topic)
        expect(topics).not_to include(pm)
        expect(topics).to include(group_pm)
      end

      it "includes all PMs when pm_translation_scope is all" do
        SiteSetting.ai_translation_target_categories = target_category.id.to_s
        SiteSetting.ai_translation_personal_messages = "all"

        topics = DiscourseAi::Translation::TopicCandidates.get
        expect(topics).to include(target_topic)
        expect(topics).to include(pm)
        expect(topics).to include(group_pm)
      end
    end
  end

  describe ".needs_localization" do
    fab!(:target_category, :category)

    before do
      SiteSetting.ai_translation_backfill_max_age_days = 100
      SiteSetting.content_localization_supported_locales = "en|ja|de"
      SiteSetting.ai_translation_target_categories = target_category.id.to_s
      SiteSetting.ai_translation_personal_messages = "none"
    end

    it "returns [topic_id, target_locale] pairs for topics needing localization" do
      topic = Fabricate(:topic, locale: "es", category: target_category)

      pairs = described_class.needs_localization(limit: 10)
      expect(pairs).to include([topic.id, "en"])
      expect(pairs).to include([topic.id, "ja"])
      expect(pairs).to include([topic.id, "de"])
    end

    it "excludes topics without a detected locale" do
      Fabricate(:topic, locale: nil, category: target_category)

      pairs = described_class.needs_localization(limit: 10)
      expect(pairs).to be_empty
    end

    it "excludes fully translated topics" do
      topic = Fabricate(:topic, locale: "es", category: target_category)
      Fabricate(:topic_localization, topic: topic, locale: "en")
      Fabricate(:topic_localization, topic: topic, locale: "ja")
      Fabricate(:topic_localization, topic: topic, locale: "de")

      pairs = described_class.needs_localization(limit: 10)
      topic_ids = pairs.map(&:first)
      expect(topic_ids).not_to include(topic.id)
    end

    it "returns only missing locale pairs for partially translated topics" do
      topic = Fabricate(:topic, locale: "es", category: target_category)
      Fabricate(:topic_localization, topic: topic, locale: "en")

      pairs = described_class.needs_localization(limit: 10)
      expect(pairs).not_to include([topic.id, "en"])
      expect(pairs).to include([topic.id, "ja"])
      expect(pairs).to include([topic.id, "de"])
    end

    it "handles base-locale deduplication (ja_JP localization covers ja target)" do
      topic = Fabricate(:topic, locale: "es", category: target_category)
      Fabricate(:topic_localization, topic: topic, locale: "en")
      Fabricate(:topic_localization, topic: topic, locale: "ja_JP")
      Fabricate(:topic_localization, topic: topic, locale: "de_DE")

      pairs = described_class.needs_localization(limit: 10)
      topic_ids = pairs.map(&:first)
      expect(topic_ids).not_to include(topic.id)
    end

    it "respects the limit parameter" do
      3.times { Fabricate(:topic, locale: "es", category: target_category) }

      pairs = described_class.needs_localization(limit: 2)
      expect(pairs.size).to eq(2)
    end

    it "returns empty when no locales are configured" do
      SiteSetting.content_localization_supported_locales = ""

      pairs = described_class.needs_localization(limit: 10)
      expect(pairs).to be_empty
    end
  end

  describe ".calculate_completion_per_locale" do
    before { SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|") }

    context "when (scenario A) 'done' determined by topic's locale" do
      it "returns total = done if all topics are in the locale" do
        locale = "pt_BR"
        Fabricate(:topic, locale:)
        Topic.update_all(locale: locale)
        Fabricate(:topic, locale: "pt")
        SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

        completion =
          DiscourseAi::Translation::TopicCandidates.calculate_completion_per_locale(locale)
        expect(completion).to eq({ done: 2, total: 2 })
      end

      it "returns correct done and total if some topics are in the locale" do
        locale = "es"
        Fabricate(:topic, locale:)
        Fabricate(:topic, locale: "not_es")
        SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

        completion =
          DiscourseAi::Translation::TopicCandidates.calculate_completion_per_locale(locale)
        expect(completion).to eq({ done: 1, total: 2 })
      end
    end

    context "when (scenario B) 'done' determined by topic localizations" do
      it "returns done = total if all topics have a localization in the locale" do
        locale = "pt_BR"
        Fabricate(:topic, locale: "en")
        Topic.all.each do |topic|
          topic.update(locale: "en")
          Fabricate(:topic_localization, topic:, locale:)
        end
        TopicLocalization.order("RANDOM()").first.update(locale: "pt")
        SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

        completion =
          DiscourseAi::Translation::TopicCandidates.calculate_completion_per_locale(locale)
        expect(completion).to eq({ done: Topic.count, total: Topic.count })
      end

      it "returns correct done and total if some topics have a localization in the locale" do
        locale = "es"
        topic1 = Fabricate(:topic, locale: "en")
        topic2 = Fabricate(:topic, locale: "fr")
        Fabricate(:topic_localization, topic: topic1, locale:)
        Fabricate(:topic_localization, topic: topic2, locale: "not_es")
        SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

        completion =
          DiscourseAi::Translation::TopicCandidates.calculate_completion_per_locale(locale)
        topics_with_locale = Topic.where.not(locale: nil).count
        expect(completion).to eq({ done: 1, total: topics_with_locale })
      end
    end

    it "returns the correct done and total based on (scenario A & B) `topic.locale` and `TopicLocalization` in the specified locale" do
      locale = "es"

      # translated candidates
      Fabricate(:topic, locale:)
      topic2 = Fabricate(:topic, locale: "en")
      Fabricate(:topic_localization, topic: topic2, locale:)

      # untranslated candidate
      topic4 = Fabricate(:topic, locale: "fr")
      Fabricate(:topic_localization, topic: topic4, locale: "zh_CN")

      # not a candidate as it is a bot topic
      topic3 = Fabricate(:topic, user: Discourse.system_user, locale: "de")
      Fabricate(:topic_localization, topic: topic3, locale:)
      SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

      completion = DiscourseAi::Translation::TopicCandidates.calculate_completion_per_locale(locale)
      translated_candidates = 2 # topic1 + topic2
      total_candidates = Topic.count - 1 # excluding the bot topic
      expect(completion).to eq({ done: translated_candidates, total: total_candidates })
    end

    it "does not allow done to exceed total when topic.locale and topic_localization both exist" do
      locale = "es"
      topic = Fabricate(:topic, locale:)
      Fabricate(:topic_localization, topic:, locale:)
      SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

      completion = DiscourseAi::Translation::TopicCandidates.calculate_completion_per_locale(locale)
      expect(completion).to eq({ done: 1, total: 1 })
    end

    it "returns nil - nil for done and total when no topics are present" do
      SiteSetting.ai_translation_backfill_max_age_days = 0

      completion = DiscourseAi::Translation::TopicCandidates.calculate_completion_per_locale("es")
      expect(completion).to eq({ done: 0, total: 0 })
    end
  end
end
