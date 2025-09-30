# frozen_string_literal: true

describe Jobs::TopicsLocaleDetectionBackfill do
  subject(:job) { described_class.new }

  fab!(:topic) { Fabricate(:topic, locale: nil) }

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.ai_translation_backfill_hourly_rate = 100
    SiteSetting.content_localization_supported_locales = "en"
  end

  it "does nothing when translator is disabled" do
    SiteSetting.discourse_ai_enabled = false
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).never

    job.execute({ limit: 10 })
  end

  it "does nothing when content translation is disabled" do
    SiteSetting.ai_translation_enabled = false
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).never

    job.execute({ limit: 10 })
  end

  it "does nothing when there are no topics to detect" do
    Topic.update_all(locale: "en")
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).never

    job.execute({ limit: 10 })
  end

  it "detects locale for topics with nil locale" do
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(topic).once
    job.execute({ limit: 10 })
  end

  it "detects most recently updated topics first" do
    topic_2 = Fabricate(:topic, locale: nil)
    topic_3 = Fabricate(:topic, locale: nil)

    topic.update!(updated_at: 3.days.ago)
    topic_2.update!(updated_at: 2.day.ago)
    topic_3.update!(updated_at: 4.day.ago)

    SiteSetting.ai_translation_backfill_hourly_rate = 12

    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(topic_2).once
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(topic).never
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(topic_3).never

    job.execute({ limit: 10 })
  end

  it "skips bot topics" do
    topic.update!(user: Discourse.system_user)
    DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(topic).never

    job.execute({ limit: 10 })
  end

  it "handles detection errors gracefully" do
    DiscourseAi::Translation::TopicLocaleDetector
      .expects(:detect_locale)
      .with(topic)
      .raises(StandardError.new("jiboomz"))
      .once

    expect { job.execute({ limit: 10 }) }.not_to raise_error
  end

  it "logs a summary after running" do
    DiscourseAi::Translation::TopicLocaleDetector.stubs(:detect_locale)
    DiscourseAi::Translation::VerboseLogger.expects(:log).with(includes("Detected 1 topic locales"))

    job.execute({ limit: 10 })
  end

  describe "with public content limitation" do
    fab!(:private_category) { Fabricate(:private_category, group: Group[:staff]) }
    fab!(:private_cat_topic) { Fabricate(:topic, category: private_category, locale: nil) }

    fab!(:group)
    fab!(:group_pm_topic) { Fabricate(:private_message_topic, allowed_groups: [group]) }

    fab!(:pm_topic) { Fabricate(:private_message_topic) }

    fab!(:public_topic) { Fabricate(:topic, locale: nil) }

    before do
      DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).at_least_once

      SiteSetting.ai_translation_backfill_limit_to_public_content = true
    end

    it "only processes topics from public categories" do
      DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(public_topic).once

      DiscourseAi::Translation::TopicLocaleDetector
        .expects(:detect_locale)
        .with(private_cat_topic)
        .never
      DiscourseAi::Translation::TopicLocaleDetector
        .expects(:detect_locale)
        .with(group_pm_topic)
        .never
      DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(pm_topic).never

      job.execute({ limit: 10 })
    end

    it "processes public category topics, group PMs, and private category topics when setting is disabled" do
      SiteSetting.ai_translation_backfill_limit_to_public_content = false

      DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(public_topic).once
      DiscourseAi::Translation::TopicLocaleDetector
        .expects(:detect_locale)
        .with(group_pm_topic)
        .once
      DiscourseAi::Translation::TopicLocaleDetector
        .expects(:detect_locale)
        .with(private_cat_topic)
        .once
      DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(pm_topic).never

      job.execute({ limit: 10 })
    end
  end

  describe "with max age limit" do
    fab!(:old_topic) { Fabricate(:topic, locale: nil, created_at: 10.days.ago) }
    fab!(:new_topic) { Fabricate(:topic, locale: nil, created_at: 2.days.ago) }

    before do
      DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).at_least_once

      SiteSetting.ai_translation_backfill_max_age_days = 5
    end

    it "only processes topics within the age limit" do
      DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(new_topic).once
      DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(old_topic).never

      job.execute({ limit: 10 })
    end

    it "processes all topics when setting is large" do
      SiteSetting.ai_translation_backfill_max_age_days = 100

      DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(new_topic).once
      DiscourseAi::Translation::TopicLocaleDetector.expects(:detect_locale).with(old_topic).once

      job.execute({ limit: 10 })
    end
  end
end
