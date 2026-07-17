# frozen_string_literal: true

describe Jobs::SidebarSectionsLocaleDetectionBackfill do
  subject(:job) { described_class.new }

  fab!(:sidebar_section) { Fabricate(:sidebar_section, public: true, locale: nil) }

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.ai_translation_backfill_hourly_rate = 100
    SiteSetting.content_localization_supported_locales = "en"
    SidebarSection.update_all(locale: "en")
    sidebar_section.update_column(:locale, nil)
  end

  it "detects locale for public sections with nil locale" do
    private_section = Fabricate(:sidebar_section, public: false, locale: nil)

    DiscourseAi::Translation::SidebarSectionLocaleDetector
      .expects(:detect_locale)
      .with(sidebar_section)
      .once
    DiscourseAi::Translation::SidebarSectionLocaleDetector
      .expects(:detect_locale)
      .with(private_section)
      .never

    job.execute({})
  end
end
