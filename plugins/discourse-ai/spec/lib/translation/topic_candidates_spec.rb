# frozen_string_literal: true

describe DiscourseAi::Translation::TopicCandidates do
  describe ".get" do
    it "does not return bot topics" do
      topic = Fabricate(:topic, user: Discourse.system_user)

      expect(DiscourseAi::Translation::TopicCandidates.get).not_to include(topic)
    end

    it "does not return topics older than ai_translation_backfill_max_age_days" do
      topic =
        Fabricate(
          :topic,
          created_at: SiteSetting.ai_translation_backfill_max_age_days.days.ago - 1.day,
        )

      expect(DiscourseAi::Translation::TopicCandidates.get).not_to include(topic)
    end

    it "does not return deleted topics" do
      topic = Fabricate(:topic, deleted_at: Time.now)

      expect(DiscourseAi::Translation::TopicCandidates.get).not_to include(topic)
    end

    describe "SiteSetting.ai_translation_backfill_limit_to_public_content" do
      fab!(:pm) { Fabricate(:private_message_topic) }
      fab!(:group_pm) { Fabricate(:private_message_topic, allowed_groups: [Fabricate(:group)]) }
      fab!(:public_topic) do
        Fabricate(:topic, category: Fabricate(:category, read_restricted: false))
      end

      it "excludes PMs and only includes topics from public categories" do
        SiteSetting.ai_translation_backfill_limit_to_public_content = true

        topics = DiscourseAi::Translation::TopicCandidates.get
        expect(topics).not_to include(pm)
        expect(topics).not_to include(group_pm)
        expect(topics).to include(public_topic)
      end

      it "includes all regular topics and group PMs but not personal PMs" do
        SiteSetting.ai_translation_backfill_limit_to_public_content = false

        topics = DiscourseAi::Translation::TopicCandidates.get
        expect(topics).not_to include(pm)
        expect(topics).to include(group_pm)
        expect(topics).to include(public_topic)
      end
    end
  end

  describe ".get_completion_per_locale" do
    context "when (scenario A) percentage determined by topic's locale" do
      it "returns 100% completion if all topics are in the locale" do
        locale = "pt_BR"
        Fabricate(:topic, locale:)
        Topic.update_all(locale: locale)
        Fabricate(:topic, locale: "pt")

        completion = DiscourseAi::Translation::TopicCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1.0)
      end

      it "returns X% completion if some topics are in the locale" do
        locale = "es"
        Fabricate(:topic, locale:)
        Fabricate(:topic, locale: "not_es")

        completion = DiscourseAi::Translation::TopicCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1 / Topic.count.to_f)
      end
    end

    context "when (scenario B) percentage determined by topic localizations" do
      it "returns 100% completion if all topics have a localization in the locale" do
        locale = "pt_BR"
        Fabricate(:topic)
        Topic.all.each { |topic| Fabricate(:topic_localization, topic:, locale:) }
        Fabricate(:topic_localization, locale: "pt")

        completion = DiscourseAi::Translation::TopicCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1.0)
      end

      it "returns X% completion if some topics have a localization in the locale" do
        locale = "es"
        Fabricate(:topic_localization, locale:)
        Fabricate(:topic_localization, locale: "not_es")

        completion = DiscourseAi::Translation::TopicCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1 / Topic.count.to_f)
      end
    end

    it "returns the correct percentage based on (scenario A & B) `topic.locale` and `TopicLocalization` in the specified locale" do
      locale = "es"

      # translated candidates
      Fabricate(:topic, locale:)
      topic2 = Fabricate(:topic)
      Fabricate(:topic_localization, topic: topic2, locale:)

      # untranslated candidate
      topic4 = Fabricate(:topic)
      Fabricate(:topic_localization, topic: topic4, locale: "zh_CN")

      # not a candidate as it is a bot topic
      topic3 = Fabricate(:topic, user: Discourse.system_user)
      Fabricate(:topic_localization, topic: topic3, locale:)

      completion = DiscourseAi::Translation::TopicCandidates.get_completion_per_locale(locale)
      translated_candidates = 2 # topic1 + topic2
      total_candidates = Topic.count - 1 # excluding the bot topic
      expect(completion).to eq(translated_candidates / total_candidates.to_f)
    end

    it "does not exceed 100% completion when topic.locale and topic_localization both exist" do
      locale = "es"
      topic = Fabricate(:topic, locale:)
      Fabricate(:topic_localization, topic:, locale:)

      completion = DiscourseAi::Translation::TopicCandidates.get_completion_per_locale(locale)
      expect(completion).to be(1.0)
    end

    it "returns 100% if no topics" do
      SiteSetting.ai_translation_backfill_max_age_days = 0
      SiteSetting.ai_translation_backfill_limit_to_public_content = false

      completion = DiscourseAi::Translation::TopicCandidates.get_completion_per_locale("es")
      expect(completion).to eq(1.0)
    end
  end
end
