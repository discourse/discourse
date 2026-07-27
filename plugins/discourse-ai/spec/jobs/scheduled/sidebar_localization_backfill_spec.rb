# frozen_string_literal: true

describe Jobs::SidebarLocalizationBackfill do
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

    expect_not_enqueued_with(job: :localize_sidebar_sections)
  end

  it "enqueues localize_sidebar_sections job with the hourly rate limit" do
    described_class.new.execute({})

    expect_job_enqueued(job: :localize_sidebar_sections, args: { limit: 100 })
  end
end
