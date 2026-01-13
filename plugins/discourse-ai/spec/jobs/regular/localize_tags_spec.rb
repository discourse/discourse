# frozen_string_literal: true

describe Jobs::LocalizeTags do
  subject(:job) { described_class.new }

  def localize_all_tags(*locales)
    Tag.all.each do |tag|
      locales.each { |locale| Fabricate(:tag_localization, tag:, locale:, name: "x") }
    end
  end

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_supported_locales = "pt_BR|zh_CN"

    Jobs.run_immediately!
  end

  it "does nothing when DiscourseAi::Translation is disabled" do
    SiteSetting.discourse_ai_enabled = false

    DiscourseAi::Translation::TagLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "does nothing when ai_translation_enabled is disabled" do
    SiteSetting.ai_translation_enabled = false

    DiscourseAi::Translation::TagLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "does nothing when no target languages are configured" do
    SiteSetting.content_localization_supported_locales = ""

    DiscourseAi::Translation::TagLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "does nothing when no tags exist" do
    Tag.destroy_all

    DiscourseAi::Translation::TagLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "skips translation when credits are unavailable" do
    DiscourseAi::Translation.expects(:credits_available_for_tag_localization?).returns(false)
    DiscourseAi::Translation::TagLocalizer.expects(:localize).never

    job.execute({ limit: 10 })
  end

  it "does nothing when the limit is zero" do
    DiscourseAi::Translation::TagLocalizer.expects(:localize).never

    expect { job.execute({}) }.to raise_error(Discourse::InvalidParameters, /limit/)
    job.execute({ limit: 0 })
  end

  it "translates tags to the configured locales" do
    tag = Fabricate(:tag, locale: "en")

    DiscourseAi::Translation::TagLocalizer
      .expects(:localize)
      .with(tag, "pt_BR", has_entries(short_text_llm_model: anything))
      .once
    DiscourseAi::Translation::TagLocalizer
      .expects(:localize)
      .with(tag, "zh_CN", has_entries(short_text_llm_model: anything))
      .once

    job.execute({ limit: 10 })
  end

  it "limits the number of localizations" do
    SiteSetting.content_localization_supported_locales = "pt"

    6.times { Fabricate(:tag, locale: "en") }

    DiscourseAi::Translation::TagLocalizer
      .expects(:localize)
      .with(is_a(Tag), "pt", has_entries(short_text_llm_model: anything))
      .times(5)

    job.execute({ limit: 5 })
  end

  it "skips tags that already have localizations" do
    tag = Fabricate(:tag, locale: "en")
    localize_all_tags("pt_BR", "zh_CN")

    DiscourseAi::Translation::TagLocalizer
      .expects(:localize)
      .with(tag, "pt_BR", has_entries(short_text_llm_model: anything))
      .never
    DiscourseAi::Translation::TagLocalizer
      .expects(:localize)
      .with(tag, "zh_CN", has_entries(short_text_llm_model: anything))
      .never

    job.execute({ limit: 10 })
  end

  it "handles translation errors gracefully" do
    tag1 = Fabricate(:tag, name: "first-tag", locale: "en")

    DiscourseAi::Translation::TagLocalizer
      .expects(:localize)
      .with(tag1, "pt_BR", has_entries(short_text_llm_model: anything))
      .once
      .raises(StandardError.new("API error"))
    DiscourseAi::Translation::TagLocalizer
      .expects(:localize)
      .with(tag1, "zh_CN", has_entries(short_text_llm_model: anything))
      .once

    expect { job.execute({ limit: 10 }) }.not_to raise_error
  end

  it "skips creating localizations in the same language as the tag's locale" do
    tag = Fabricate(:tag, locale: "pt")

    DiscourseAi::Translation::TagLocalizer
      .expects(:localize)
      .with(tag, "pt", has_entries(short_text_llm_model: anything))
      .never
    DiscourseAi::Translation::TagLocalizer
      .expects(:localize)
      .with(tag, "zh_CN", has_entries(short_text_llm_model: anything))
      .once

    job.execute({ limit: 10 })
  end

  it "deletes existing localizations that match each tag's locale" do
    tag1 = Fabricate(:tag, locale: "pt")
    tag2 = Fabricate(:tag, locale: "zh_CN")
    Fabricate(:tag_localization, tag: tag1, locale: "pt")
    Fabricate(:tag_localization, tag: tag1, locale: "zh_CN")
    Fabricate(:tag_localization, tag: tag2, locale: "pt")
    Fabricate(:tag_localization, tag: tag2, locale: "zh_CN")

    DiscourseAi::Translation::TagLocalizer.stubs(:localize)

    job.execute({ limit: 10 })

    expect(TagLocalization.where(tag: tag1).pluck(:locale)).to eq(%w[zh_CN])
    expect(TagLocalization.where(tag: tag2).pluck(:locale)).to eq(%w[pt])
  end

  it "doesn't process tags with nil locale" do
    nil_locale_tag = Fabricate(:tag, name: "no-locale", locale: nil)

    DiscourseAi::Translation::TagLocalizer
      .expects(:localize)
      .with(nil_locale_tag, any_parameters)
      .never

    job.execute({ limit: 10 })
  end
end
