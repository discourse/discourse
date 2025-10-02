# frozen_string_literal: true

describe Jobs::CategoriesLocaleDetectionBackfill do
  subject(:job) { described_class.new }

  fab!(:category) { Fabricate(:category, locale: nil) }

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.ai_translation_backfill_hourly_rate = 100
    SiteSetting.content_localization_supported_locales = "en"
  end

  it "does nothing when AI is disabled" do
    SiteSetting.discourse_ai_enabled = false
    DiscourseAi::Translation::CategoryLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "does nothing when content translation is disabled" do
    SiteSetting.ai_translation_enabled = false
    DiscourseAi::Translation::CategoryLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "does nothing when backfill rate is 0" do
    SiteSetting.ai_translation_backfill_hourly_rate = 0
    DiscourseAi::Translation::CategoryLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "does nothing when there are no categories to detect" do
    Category.update_all(locale: "en")
    DiscourseAi::Translation::CategoryLocaleDetector.expects(:detect_locale).never

    job.execute({})
  end

  it "detects locale for categories with nil locale" do
    DiscourseAi::Translation::CategoryLocaleDetector
      .expects(:detect_locale)
      .with(is_a(Category))
      .times(Category.count)

    job.execute({})
  end

  it "handles detection errors gracefully" do
    DiscourseAi::Translation::CategoryLocaleDetector
      .expects(:detect_locale)
      .with(is_a(Category))
      .at_least_once
    DiscourseAi::Translation::CategoryLocaleDetector
      .expects(:detect_locale)
      .with(category)
      .raises(StandardError.new("error"))
      .once

    expect { job.execute({}) }.not_to raise_error
  end

  it "logs a summary after running" do
    DiscourseAi::Translation::CategoryLocaleDetector.stubs(:detect_locale)
    DiscourseAi::Translation::VerboseLogger.expects(:log).with(
      includes("Detected #{Category.count} category locales"),
    )

    job.execute({})
  end

  describe "with public content limitation" do
    fab!(:private_category) { Fabricate(:private_category, group: Group[:staff], locale: nil) }

    before do
      # catch-all for other categories
      DiscourseAi::Translation::CategoryLocaleDetector
        .expects(:detect_locale)
        .with(is_a(Category))
        .at_least_once

      SiteSetting.ai_translation_backfill_limit_to_public_content = true
    end

    it "only processes public categories" do
      DiscourseAi::Translation::CategoryLocaleDetector.expects(:detect_locale).with(category).once
      DiscourseAi::Translation::CategoryLocaleDetector
        .expects(:detect_locale)
        .with(private_category)
        .never

      job.execute({})
    end

    it "processes all categories when setting is disabled" do
      SiteSetting.ai_translation_backfill_limit_to_public_content = false

      DiscourseAi::Translation::CategoryLocaleDetector.expects(:detect_locale).with(category).once
      DiscourseAi::Translation::CategoryLocaleDetector
        .expects(:detect_locale)
        .with(private_category)
        .once

      job.execute({})
    end
  end

  it "limits processing to the backfill rate" do
    SiteSetting.ai_translation_backfill_hourly_rate = 1
    Fabricate(:category, locale: nil)

    DiscourseAi::Translation::CategoryLocaleDetector.expects(:detect_locale).once

    job.execute({})
  end
end
