# frozen_string_literal: true

describe Jobs::PostLocalizationBackfill do
  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_translation_backfill_hourly_rate = 100
    SiteSetting.content_localization_supported_locales = "en"
    SiteSetting.ai_translation_enabled = true
  end

  it "does not enqueue post translation when translator disabled" do
    SiteSetting.discourse_ai_enabled = false

    described_class.new.execute({})

    expect_not_enqueued_with(job: :localize_posts)
  end

  it "does not enqueue post translation when experimental translation disabled" do
    SiteSetting.ai_translation_enabled = false

    described_class.new.execute({})

    expect_not_enqueued_with(job: :localize_posts)
  end

  it "does not enqueue post translation if backfill languages are not set" do
    SiteSetting.content_localization_supported_locales = ""

    described_class.new.execute({})

    expect_not_enqueued_with(job: :localize_posts)
  end

  it "does not enqueue post translation if backfill limit is set to 0" do
    SiteSetting.ai_translation_enabled = true
    SiteSetting.ai_translation_backfill_hourly_rate = 0

    described_class.new.execute({})

    expect_not_enqueued_with(job: :localize_posts)
  end

  it "enqueues post translation with correct limit" do
    SiteSetting.ai_translation_enabled = true
    SiteSetting.ai_translation_backfill_hourly_rate = 100

    described_class.new.execute({})

    expect_job_enqueued(job: :localize_posts, args: { limit: 8 })
  end
end
