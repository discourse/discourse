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
    SiteSetting.content_localization_supported_locales = ""
    DiscourseAi::Translation::ShortTextTranslator.expects(:new).never
    job.execute(theme_id: theme.id)
  end

  it "translates each key into every non-source locale and upserts overrides" do
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
    SiteSetting.content_localization_supported_locales = "fr"
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

  it "uses the en override value when present instead of the yaml default" do
    ThemeTranslationOverride.create!(
      theme_id: theme.id,
      locale: "en",
      translation_key: "greeting",
      value: "Howdy",
    )

    translator = mock
    translator.stubs(:translate).returns("translated")
    DiscourseAi::Translation::ShortTextTranslator
      .expects(:new)
      .with(has_entries(text: "Howdy"))
      .at_least_once
      .returns(translator)

    job.execute(theme_id: theme.id)
  end

  describe "with a non-en source locale" do
    before do
      theme.set_field(target: :translations, name: "fr", value: <<~YAML)
        fr:
          greeting: "Bonjour"
      YAML
      theme.save!
    end

    it "uses the source locale override when present" do
      ThemeTranslationOverride.create!(
        theme_id: theme.id,
        locale: "fr",
        translation_key: "greeting",
        value: "Salut",
      )

      translator = mock
      translator.stubs(:translate).returns("translated")
      DiscourseAi::Translation::ShortTextTranslator.stubs(:new).returns(translator)
      DiscourseAi::Translation::ShortTextTranslator
        .expects(:new)
        .with(has_entries(text: "Salut", target_locale: "es"))
        .returns(translator)

      job.execute(theme_id: theme.id, source_locale: "fr")

      expect(
        ThemeTranslationOverride.where(theme_id: theme.id, value: "translated").pluck(:locale),
      ).to contain_exactly("en", "es")
    end

    it "falls back to the source locale yaml when no source override exists" do
      translator = mock
      translator.stubs(:translate).returns("translated")
      DiscourseAi::Translation::ShortTextTranslator.stubs(:new).returns(translator)
      DiscourseAi::Translation::ShortTextTranslator
        .expects(:new)
        .with(has_entries(text: "Bonjour", target_locale: "es"))
        .returns(translator)

      job.execute(theme_id: theme.id, source_locale: "fr")
    end

    it "falls back to en override, then en yaml, when source locale has neither and translates into the source locale too" do
      theme.theme_fields.find_by(target_id: Theme.targets[:translations], name: "fr").destroy!
      ThemeTranslationOverride.create!(
        theme_id: theme.id,
        locale: "en",
        translation_key: "greeting",
        value: "Howdy",
      )

      translator = mock
      translator.stubs(:translate).returns("translated")
      DiscourseAi::Translation::ShortTextTranslator
        .expects(:new)
        .with(has_entries(text: "Howdy", target_locale: "fr"))
        .returns(translator)
      DiscourseAi::Translation::ShortTextTranslator
        .expects(:new)
        .with(has_entries(text: "Howdy", target_locale: "es"))
        .returns(translator)

      job.execute(theme_id: theme.id, source_locale: "fr")
    end

    it "invalidates the baked theme JS so new locales reach the browser" do
      theme.theme_fields.where(target_id: Theme.targets[:translations]).each(&:ensure_baked!)
      baked_before =
        theme
          .theme_fields
          .where(target_id: Theme.targets[:translations])
          .pluck(:value_baked)
          .compact
      expect(baked_before).not_to be_empty

      translator = mock
      translator.stubs(:translate).returns("translated")
      DiscourseAi::Translation::ShortTextTranslator.stubs(:new).returns(translator)
      Theme.any_instance.expects(:remove_from_cache!).at_least_once

      job.execute(theme_id: theme.id, source_locale: "fr")

      expect(
        theme.theme_fields.where(target_id: Theme.targets[:translations]).pluck(:value_baked),
      ).to all(be_nil)
    end

    it "still invalidates the baked theme JS when updating an existing override" do
      ThemeTranslationOverride.create!(
        theme_id: theme.id,
        locale: "es",
        translation_key: "greeting",
        value: "stale",
      )
      theme.theme_fields.where(target_id: Theme.targets[:translations]).each(&:ensure_baked!)

      translator = mock
      translator.stubs(:translate).returns("translated")
      DiscourseAi::Translation::ShortTextTranslator.stubs(:new).returns(translator)

      job.execute(theme_id: theme.id, source_locale: "fr")

      expect(
        theme.theme_fields.where(target_id: Theme.targets[:translations]).pluck(:value_baked),
      ).to all(be_nil)
      expect(
        ThemeTranslationOverride.find_by(
          theme_id: theme.id,
          locale: "es",
          translation_key: "greeting",
        ).value,
      ).to eq("translated")
    end

    it "excludes only the effective source locale from target locales per key" do
      theme.set_field(target: :translations, name: "en", value: <<~YAML)
        en:
          greeting: "Hello"
          farewell: "Goodbye"
      YAML
      theme.save!

      translator = mock
      translator.stubs(:translate).returns("translated")
      DiscourseAi::Translation::ShortTextTranslator.stubs(:new).returns(translator)

      job.execute(theme_id: theme.id, source_locale: "fr")

      greeting_locales =
        ThemeTranslationOverride.where(
          theme_id: theme.id,
          translation_key: "greeting",
          value: "translated",
        ).pluck(:locale)
      farewell_locales =
        ThemeTranslationOverride.where(
          theme_id: theme.id,
          translation_key: "farewell",
          value: "translated",
        ).pluck(:locale)

      # greeting has a fr yaml → effective source fr → targets en and es
      expect(greeting_locales).to contain_exactly("en", "es")
      # farewell has no fr anywhere → effective source en → targets fr and es
      expect(farewell_locales).to contain_exactly("fr", "es")
    end
  end
end
