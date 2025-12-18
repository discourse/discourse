# frozen_string_literal: true

describe Jobs::TagLocalizationBackfill do
  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_translation_enabled = true
    SiteSetting.ai_translation_backfill_hourly_rate = 100
    SiteSetting.ai_translation_backfill_max_age_days = 30
    SiteSetting.content_localization_supported_locales = "pt_BR|zh_CN"
  end

  it "does not enqueue when AI is disabled" do
    SiteSetting.discourse_ai_enabled = false

    described_class.new.execute({})

    expect_not_enqueued_with(job: :localize_tags)
  end

  it "does not enqueue when translation is disabled" do
    SiteSetting.ai_translation_enabled = false

    described_class.new.execute({})

    expect_not_enqueued_with(job: :localize_tags)
  end

  it "does not enqueue when backfill rate is 0" do
    SiteSetting.ai_translation_backfill_hourly_rate = 0

    described_class.new.execute({})

    expect_not_enqueued_with(job: :localize_tags)
  end

  it "enqueues localize_tags job with the hourly rate limit" do
    described_class.new.execute({})

    expect_job_enqueued(job: :localize_tags, args: { limit: 100 })
  end

  it "does not enqueue when credits are unavailable" do
    llm_model = Fabricate(:llm_model)
    short_text_persona = Fabricate(:ai_persona)
    short_text_persona.update!(default_llm_id: llm_model.id)
    SiteSetting.ai_translation_short_text_translator_persona = short_text_persona.id

    LlmCreditAllocation.stubs(:credits_available?).with(llm_model).returns(false)

    described_class.new.execute({})

    expect_not_enqueued_with(job: :localize_tags)
  end
end
