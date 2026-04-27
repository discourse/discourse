# frozen_string_literal: true

describe Jobs::LocalizeTopics do
  subject(:job) { described_class.new }

  fab!(:topic)

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_supported_locales = "en|ja|de"
    SiteSetting.ai_translation_backfill_hourly_rate = 100
    SiteSetting.ai_translation_backfill_max_age_days = 100
  end

  it "does nothing when translator is disabled" do
    SiteSetting.discourse_ai_enabled = false
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ pairs: [[topic.id, "ja"]] })
  end

  it "does nothing when ai_translation_enabled is disabled" do
    SiteSetting.ai_translation_enabled = false
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ pairs: [[topic.id, "ja"]] })
  end

  it "does nothing when no target languages are configured" do
    SiteSetting.content_localization_supported_locales = ""
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ pairs: [[topic.id, "ja"]] })
  end

  it "skips translation when credits are unavailable" do
    DiscourseAi::Translation.expects(:credits_available_for_topic_localization?).returns(false)
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ pairs: [[topic.id, "ja"]] })
  end

  it "skips pairs where topic is not found" do
    DiscourseAi::Translation::TopicLocalizer.expects(:localize).never

    job.execute({ pairs: [[-1, "ja"]] })
  end

  it "translates each pair it receives" do
    DiscourseAi::Translation::TopicLocalizer
      .expects(:localize)
      .with(topic, "en", has_entries(topic_title_llm_model: anything, post_raw_llm_model: anything))
      .once
    DiscourseAi::Translation::TopicLocalizer
      .expects(:localize)
      .with(topic, "ja", has_entries(topic_title_llm_model: anything, post_raw_llm_model: anything))
      .once

    job.execute({ pairs: [[topic.id, "en"], [topic.id, "ja"]] })
  end

  it "handles translation errors gracefully" do
    DiscourseAi::Translation::TopicLocalizer
      .expects(:localize)
      .with(topic, "en", has_entries(topic_title_llm_model: anything, post_raw_llm_model: anything))
      .raises(StandardError.new("API error"))
    DiscourseAi::Translation::TopicLocalizer
      .expects(:localize)
      .with(topic, "ja", has_entries(topic_title_llm_model: anything, post_raw_llm_model: anything))
      .once

    expect { job.execute({ pairs: [[topic.id, "en"], [topic.id, "ja"]] }) }.not_to raise_error
  end

  it "logs a summary after translation" do
    DiscourseAi::Translation::TopicLocalizer.stubs(:localize)
    DiscourseAi::Translation::VerboseLogger.expects(:log).with(
      includes("Translated 2/2 topic localizations"),
    )

    job.execute({ pairs: [[topic.id, "en"], [topic.id, "ja"]] })
  end
end
