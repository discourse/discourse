# frozen_string_literal: true

describe Jobs::LocalizeThemeTranslations do
  subject(:job) { described_class.new }

  fab!(:theme)

  before do
    enable_current_plugin
    SiteSetting.content_localization_supported_locales = "en|fr|es"

    theme.set_field(target: :translations, name: "en", value: <<~YAML)
      en:
        greeting: "Hello"
    YAML
    theme.save!
  end

  it "raises when theme_id is missing" do
    expect { job.execute({}) }.to raise_error(Discourse::InvalidParameters)
  end

  it "does nothing when the theme does not exist" do
    DiscourseAi::Translation::ShortTextTranslator.expects(:new).never
    job.execute(theme_id: -999)
  end

  it "does nothing when no target locales are configured" do
    SiteSetting.content_localization_supported_locales = "en"
    DiscourseAi::Translation::ShortTextTranslator.expects(:new).never
    job.execute(theme_id: theme.id)
  end

  it "translates each key into every non-en locale and upserts overrides" do
    translator = mock
    translator.stubs(:translate).returns("translated")
    DiscourseAi::Translation::ShortTextTranslator.stubs(:new).returns(translator)

    job.execute(theme_id: theme.id)

    overrides = ThemeTranslationOverride.where(theme_id: theme.id)
    expect(overrides.pluck(:locale)).to contain_exactly("fr", "es")
    expect(overrides.pluck(:value).uniq).to eq(["translated"])
    expect(overrides.pluck(:translation_key).uniq).to eq(["greeting"])
  end

  it "only translates to locales in content_localization_supported_locales" do
    SiteSetting.content_localization_supported_locales = "en|fr"
    translator = mock
    translator.stubs(:translate).returns("translated")
    DiscourseAi::Translation::ShortTextTranslator.stubs(:new).returns(translator)

    job.execute(theme_id: theme.id)

    expect(ThemeTranslationOverride.where(theme_id: theme.id).pluck(:locale)).to contain_exactly(
      "fr",
    )
  end

  it "skips empty translations" do
    translator = mock
    translator.stubs(:translate).returns("")
    DiscourseAi::Translation::ShortTextTranslator.stubs(:new).returns(translator)

    job.execute(theme_id: theme.id)

    expect(ThemeTranslationOverride.where(theme_id: theme.id)).to be_empty
  end
end
