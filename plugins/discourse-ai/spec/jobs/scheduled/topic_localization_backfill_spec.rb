# frozen_string_literal: true

describe Jobs::TopicLocalizationBackfill do
  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_translation_backfill_hourly_rate = 100
    SiteSetting.content_localization_supported_locales = "en"
    SiteSetting.ai_translation_enabled = true
  end

  it "does not enqueue topic translation when translator disabled" do
    SiteSetting.discourse_ai_enabled = false

    expect_not_enqueued_with(job: :localize_topics) { described_class.new.execute({}) }
  end

  it "does not enqueue topic translation when ai_translation_enabled disabled" do
    SiteSetting.ai_translation_enabled = false

    expect_not_enqueued_with(job: :localize_topics) { described_class.new.execute({}) }
  end

  it "does not enqueue topic translation if backfill languages are not set" do
    SiteSetting.content_localization_supported_locales = ""

    expect_not_enqueued_with(job: :localize_topics) { described_class.new.execute({}) }
  end

  it "does not enqueue topic translation if backfill limit is set to 0" do
    SiteSetting.ai_translation_backfill_hourly_rate = 0

    expect_not_enqueued_with(job: :localize_topics) { described_class.new.execute({}) }
  end

  it "enqueues topic translation with correct limit" do
    SiteSetting.ai_translation_backfill_hourly_rate = 100

    described_class.new.execute({})

    expect_job_enqueued(job: :localize_topics, args: { limit: 8 })
  end
end
