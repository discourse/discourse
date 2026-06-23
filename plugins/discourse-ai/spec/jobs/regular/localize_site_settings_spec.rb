# frozen_string_literal: true

describe Jobs::LocalizeSiteSettings do
  subject(:job) { described_class.new }

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_supported_locales = "pt_BR|zh_CN"
    SiteSetting.default_locale = "en"
    SiteSetting.title = "English community"
    SiteSetting.site_description = "English summary"
    SiteSettingLocalization.stubs(:localizable_setting_names).returns(%w[title site_description])

    Jobs.run_immediately!
  end

  it "does nothing when translation is disabled" do
    SiteSetting.ai_translation_enabled = false

    DiscourseAi::Translation::SiteSettingLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "skips translation when credits are unavailable" do
    DiscourseAi::Translation.expects(:credits_available_for_site_setting_localization?).returns(
      false,
    )
    DiscourseAi::Translation::SiteSettingLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "requires a limit" do
    DiscourseAi::Translation::SiteSettingLocalizer.expects(:localize).never

    expect { job.execute({}) }.to raise_error(Discourse::InvalidParameters, /limit/)
    job.execute({ limit: 0 })
  end

  it "translates missing site setting localizations" do
    DiscourseAi::Translation::SiteSettingLocalizer
      .expects(:localize)
      .with(
        "title",
        "pt_BR",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .once
    DiscourseAi::Translation::SiteSettingLocalizer
      .expects(:localize)
      .with(
        "title",
        "zh_CN",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .once
    DiscourseAi::Translation::SiteSettingLocalizer
      .expects(:localize)
      .with(
        "site_description",
        "pt_BR",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .once
    DiscourseAi::Translation::SiteSettingLocalizer
      .expects(:localize)
      .with(
        "site_description",
        "zh_CN",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .once

    job.execute({ limit: 10 })
  end

  it "limits the number of localizations" do
    DiscourseAi::Translation::SiteSettingLocalizer
      .expects(:localize)
      .with(is_a(String), is_a(String), has_entries(short_text_llm_model: anything))
      .times(2)

    job.execute({ limit: 2 })
  end

  it "skips settings that already have localizations" do
    SiteSettingLocalization.stubs(:localizable_setting_names).returns(%w[title])
    SiteSettingLocalization.create!(setting_name: "title", locale: "pt_BR", value: "Comunidade")

    DiscourseAi::Translation::SiteSettingLocalizer
      .expects(:localize)
      .with("title", "pt_BR", anything)
      .never
    DiscourseAi::Translation::SiteSettingLocalizer
      .expects(:localize)
      .with(
        "title",
        "zh_CN",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .once

    job.execute({ limit: 10 })
  end

  it "skips the default locale and removes matching rows" do
    SiteSettingLocalization.stubs(:localizable_setting_names).returns(%w[title])
    SiteSetting.content_localization_supported_locales = "en|ja"
    SiteSettingLocalization.create!(setting_name: "title", locale: "en", value: "Localized English")

    DiscourseAi::Translation::SiteSettingLocalizer
      .expects(:localize)
      .with("title", "en", anything)
      .never
    DiscourseAi::Translation::SiteSettingLocalizer
      .expects(:localize)
      .with(
        "title",
        "ja",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .once

    job.execute({ limit: 10 })

    expect(SiteSettingLocalization.exists?(setting_name: "title", locale: "en")).to eq(false)
  end

  it "handles translation errors gracefully" do
    SiteSettingLocalization.stubs(:localizable_setting_names).returns(%w[title])
    DiscourseAi::Translation::SiteSettingLocalizer
      .expects(:localize)
      .with(
        "title",
        "pt_BR",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .raises(StandardError.new("API error"))
    DiscourseAi::Translation::SiteSettingLocalizer
      .expects(:localize)
      .with(
        "title",
        "zh_CN",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .once

    expect { job.execute({ limit: 10 }) }.not_to raise_error
  end
end
