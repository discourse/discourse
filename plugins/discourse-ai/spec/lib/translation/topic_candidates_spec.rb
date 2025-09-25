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
    context "when (scenario A) 'done' determined by topic's locale" do
      it "returns total = done if all topics are in the locale" do
        locale = "pt_BR"
        Fabricate(:topic, locale:)
        Topic.update_all(locale: locale)
        Fabricate(:topic, locale: "pt")

        completion = DiscourseAi::Translation::TopicCandidates.get_completion_per_locale(locale)
        expect(completion).to eq({ done: 2, total: 2 })
      end

      it "returns correct done and total if some topics are in the locale" do
        locale = "es"
        Fabricate(:topic, locale:)
        Fabricate(:topic, locale: "not_es")

        completion = DiscourseAi::Translation::TopicCandidates.get_completion_per_locale(locale)
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

        completion = DiscourseAi::Translation::TopicCandidates.get_completion_per_locale(locale)
        expect(completion).to eq({ done: Topic.count, total: Topic.count })
      end

      it "returns correct done and total if some topics have a localization in the locale" do
        locale = "es"
        topic1 = Fabricate(:topic, locale: "en")
        topic2 = Fabricate(:topic, locale: "fr")
        Fabricate(:topic_localization, topic: topic1, locale:)
        Fabricate(:topic_localization, topic: topic2, locale: "not_es")

        completion = DiscourseAi::Translation::TopicCandidates.get_completion_per_locale(locale)
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

      completion = DiscourseAi::Translation::TopicCandidates.get_completion_per_locale(locale)
      translated_candidates = 2 # topic1 + topic2
      total_candidates = Topic.count - 1 # excluding the bot topic
      expect(completion).to eq({ done: translated_candidates, total: total_candidates })
    end

    it "does not allow done to exceed total when topic.locale and topic_localization both exist" do
      locale = "es"
      topic = Fabricate(:topic, locale:)
      Fabricate(:topic_localization, topic:, locale:)

      completion = DiscourseAi::Translation::TopicCandidates.get_completion_per_locale(locale)
      expect(completion).to eq({ done: 1, total: 1 })
    end

    it "returns nil - nil for done and total when no topics are present" do
      SiteSetting.ai_translation_backfill_max_age_days = 0

      completion = DiscourseAi::Translation::TopicCandidates.get_completion_per_locale("es")
      expect(completion).to eq({ done: 0, total: 0 })
    end
  end
end
