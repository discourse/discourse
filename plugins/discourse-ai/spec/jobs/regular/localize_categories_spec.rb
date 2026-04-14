# frozen_string_literal: true

describe Jobs::LocalizeCategories do
  subject(:job) { described_class.new }

  def localize_all_categories(*locales)
    Category.all.each do |category|
      locales.each { |locale| Fabricate(:category_localization, category:, locale:, name: "x") }
    end
  end

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.default_locale = "pt_BR"
    SiteSetting.content_localization_supported_locales = "pt_BR|zh_CN"

    Jobs.run_immediately!
  end

  it "does nothing when DiscourseAi::Translation::CategoryLocalizer is disabled" do
    SiteSetting.discourse_ai_enabled = false

    DiscourseAi::Translation::CategoryLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "does nothing when ai_translation_enabled is disabled" do
    SiteSetting.ai_translation_enabled = false

    DiscourseAi::Translation::CategoryLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "does nothing when no target languages are configured" do
    SiteSetting.content_localization_supported_locales = ""

    DiscourseAi::Translation::CategoryLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "does nothing when no categories exist" do
    Category.destroy_all

    DiscourseAi::Translation::CategoryLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "skips translation when credits are unavailable" do
    DiscourseAi::Translation.expects(:credits_available_for_category_localization?).returns(false)
    DiscourseAi::Translation::CategoryLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "does nothing when the limit is zero" do
    DiscourseAi::Translation::CategoryLocalizer.expects(:localize).never

    expect { job.execute({}) }.to raise_error(Discourse::InvalidParameters, /limit/)
    job.execute({ limit: 0 })
  end

  it "translates categories to the configured locales" do
    SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")
    Category.update_all(locale: "en")
    number_of_categories = Category.count

    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(
        is_a(Category),
        "pt_BR",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .times(number_of_categories)
    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(
        is_a(Category),
        "zh_CN",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .times(number_of_categories)

    job.execute({ limit: 10 })
  end

  it "limits the number of localizations" do
    SiteSetting.default_locale = "pt"
    SiteSetting.content_localization_supported_locales = "pt"

    6.times { Fabricate(:category) }
    SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")
    Category.update_all(locale: "en")

    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(
        is_a(Category),
        "pt",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .times(5)

    job.execute({ limit: 5 })
  end

  it "skips categories that already have localizations" do
    SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")
    localize_all_categories("pt", "zh_CN")

    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(
        is_a(Category),
        "pt_BR",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .never
    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(
        is_a(Category),
        "zh_CN",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .never

    job.execute({ limit: 10 })
  end

  it "handles translation errors gracefully" do
    SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")
    localize_all_categories("pt", "zh_CN")

    category1 = Fabricate(:category, name: "First", description: "First description", locale: "en")
    SiteSetting.ai_translation_target_categories =
      (SiteSetting.ai_translation_target_categories.split("|") + [category1.id.to_s]).join("|")

    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(
        category1,
        "pt_BR",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .once
      .raises(StandardError.new("API error"))
    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(
        category1,
        "zh_CN",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .once

    expect { job.execute({ limit: 10 }) }.not_to raise_error
  end

  it "only translates categories in target_categories" do
    target = Fabricate(:category, locale: "en")
    non_target = Fabricate(:category, locale: "en")
    SiteSetting.ai_translation_target_categories = target.id.to_s

    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(target, any_parameters)
      .twice
    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(non_target, any_parameters)
      .never

    job.execute({ limit: 10 })
  end

  it "skips creating localizations in the same language as the category's locale" do
    SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")
    Category.update_all(locale: "pt")

    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(
        is_a(Category),
        "pt",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .never
    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(
        is_a(Category),
        "zh_CN",
        has_entries(short_text_llm_model: anything, post_raw_llm_model: anything),
      )
      .times(Category.count)

    job.execute({ limit: 10 })
  end

  it "deletes existing localizations that match the category's locale" do
    SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")
    # update all categories to portuguese
    Category.update_all(locale: "pt")

    localize_all_categories("pt", "zh_CN")

    expect { job.execute({ limit: 10 }) }.to change {
      CategoryLocalization.exists?(locale: "pt")
    }.from(true).to(false)
  end

  it "doesn't process categories with nil locale" do
    # Add a category with nil locale
    nil_locale_category = Fabricate(:category, name: "No Locale", locale: nil)
    SiteSetting.ai_translation_target_categories = nil_locale_category.id.to_s

    # Make sure our query for categories with non-null locales excludes it
    DiscourseAi::Translation::CategoryLocalizer
      .expects(:localize)
      .with(nil_locale_category, any_parameters)
      .never

    job.execute({ limit: 10 })
  end
end
