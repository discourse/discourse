# frozen_string_literal: true

describe Jobs::LocalizeTopics do
  subject(:job) { described_class.new }

  fab!(:topic)

  let(:locales) { %w[en ja de] }

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_supported_locales = locales.join("|")
    SiteSetting.ai_translation_backfill_hourly_rate = 100
    SiteSetting.ai_translation_backfill_max_age_days = 100
  end

  it "does nothing when translator is disabled" do
    SiteSetting.discourse_ai_enabled = false
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "does nothing when ai_translation_enabled is disabled" do
    SiteSetting.ai_translation_enabled = false
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "does nothing when no target languages are configured" do
    SiteSetting.content_localization_supported_locales = ""
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "does nothing when there are no topics to translate" do
    Topic.destroy_all
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "skips topics that already have localizations" do
    Topic.all.each do |topic|
      Fabricate(:topic_localization, topic:, locale: "en")
      Fabricate(:topic_localization, topic:, locale: "ja")
    end
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "skips bot topics" do
    topic.update!(user: Discourse.system_user)
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "en").never
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "ja").never

    job.execute({ limit: 10 })
  end

  it "handles translation errors gracefully" do
    topic.update(locale: "es")
    DiscourseAi::Translation::TopicLocalizer
      .expects(:localize)
      .with(topic, "en")
      .raises(StandardError.new("API error"))
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "ja").once
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "de").once

    expect { job.execute({ limit: 10 }) }.not_to raise_error
  end

  it "logs a summary after translation" do
    topic.update(locale: "es")
    DiscourseAi::Translation::TopicLocalizer.stubs(:localize)
    DiscourseAi::Translation::VerboseLogger.expects(:log).with(
      includes("Translated 1 topics to en"),
    )
    DiscourseAi::Translation::VerboseLogger.expects(:log).with(
      includes("Translated 1 topics to ja"),
    )
    DiscourseAi::Translation::VerboseLogger.expects(:log).with(
      includes("Translated 1 topics to de"),
    )

    job.execute({ limit: 10 })
  end

  context "for translation scenarios" do
    it "scenario 1: skips topic when locale is not set" do
      DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

      job.execute({ limit: 10 })
    end

    it "scenario 2: returns topic with locale 'es' if localizations for en/ja/de do not exist" do
      topic = Fabricate(:topic, locale: "es")

      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "en").once
      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "ja").once
      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "de").once

      job.execute({ limit: 10 })
    end

    it "scenario 3: returns topic with locale 'en' if ja/de localization does not exist" do
      topic = Fabricate(:topic, locale: "en")

      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "ja").once
      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "de").once
      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(topic, "en").never

      job.execute({ limit: 10 })
    end

    it "scenario 4: skips topic with locale 'en' if all localizations exist" do
      topic = Fabricate(:topic, locale: "en")
      Fabricate(:topic_localization, topic: topic, locale: "ja")
      Fabricate(:topic_localization, topic: topic, locale: "de")

      DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

      job.execute({ limit: 10 })
    end

    it "scenario 5: skips topic that already have localizations in similar language variant" do
      topic = Fabricate(:topic, locale: "en")
      Fabricate(:topic_localization, topic: topic, locale: "ja_JP")
      Fabricate(:topic_localization, topic: topic, locale: "de_DE")

      DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

      job.execute({ limit: 10 })
    end
  end

  describe "with public content limitation" do
    fab!(:private_category) { Fabricate(:private_category, group: Group[:staff]) }
    fab!(:private_topic) { Fabricate(:topic, category: private_category, locale: "es") }
    fab!(:public_topic) { Fabricate(:topic, locale: "es") }

    fab!(:personal_pm_topic) { Fabricate(:private_message_topic, locale: "es") }

    fab!(:group_pm_topic) do
      Fabricate(:group_private_message_topic, recipient_group: Fabricate(:group), locale: "es")
    end

    before { SiteSetting.content_localization_supported_locales = "ja" }

    context "when ai_translation_backfill_limit_to_public_content is true" do
      before { SiteSetting.ai_translation_backfill_limit_to_public_content = true }

      it "only processes topics from public categories" do
        DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(public_topic, "ja").once

        DiscourseAi::Translation::TopicLocalizer
          .expects(:localize)
          .with(private_topic, any_parameters)
          .never

        DiscourseAi::Translation::TopicLocalizer
          .expects(:localize)
          .with(personal_pm_topic, any_parameters)
          .never

        DiscourseAi::Translation::TopicLocalizer
          .expects(:localize)
          .with(group_pm_topic, any_parameters)
          .never

        job.execute({ limit: 10 })
      end
    end

    context "when ai_translation_backfill_limit_to_public_content is false" do
      before { SiteSetting.ai_translation_backfill_limit_to_public_content = false }

      it "processes public topics, private topics and group PMs but not personal PMs" do
        DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(public_topic, "ja").once

        DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(private_topic, "ja").once

        DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(group_pm_topic, "ja").once

        DiscourseAi::Translation::TopicLocalizer
          .expects(:localize)
          .with(personal_pm_topic, any_parameters)
          .never

        job.execute({ limit: 10 })
      end
    end
  end

  describe "with max age limit" do
    fab!(:old_topic) { Fabricate(:topic, locale: "es", created_at: 10.days.ago) }
    fab!(:new_topic) { Fabricate(:topic, locale: "es", created_at: 2.days.ago) }

    before { SiteSetting.ai_translation_backfill_max_age_days = 5 }

    it "only processes topics within the age limit" do
      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(new_topic, "en").once
      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(new_topic, "ja").once
      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(new_topic, "de").once

      DiscourseAi::Translation::TopicLocalizer
        .expects(:localize)
        .with(old_topic, any_parameters)
        .never

      job.execute({ limit: 10 })
    end

    it "processes all topics when setting is more than the post age" do
      SiteSetting.ai_translation_backfill_max_age_days = 100

      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(new_topic, "en").once
      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(new_topic, "ja").once
      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(new_topic, "de").once

      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(old_topic, "en").once
      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(old_topic, "ja").once
      DiscourseAi::Translation::TopicLocalizer.expects(:localize).with(old_topic, "de").once

      job.execute({ limit: 10 })
    end
  end
end
