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

  it "only translates to confirmed targets that are still supported" do
    translator = mock
    translator.stubs(:translate).returns("translated")
    DiscourseAi::Translation::ShortTextTranslator.stubs(:new).returns(translator)

    job.execute(theme_id: theme.id, target_locales: %w[en fr ja])

    expect(theme.theme_translation_overrides.reload.pluck(:locale)).to eq(["fr"])
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

  it "translates object-editor text alongside locale-file text" do
    theme.set_field(
      target: :settings,
      name: "yaml",
      value: File.read(file_from_fixtures("translatable_objects.yaml", "theme_settings")),
    )
    theme.save!
    translator = mock
    translator.stubs(:translate).returns("translated")
    DiscourseAi::Translation::ShortTextTranslator.stubs(:new).returns(translator)

    job.execute(theme_id: theme.id)

    expect(
      theme.theme_translation_overrides.where(locale: "fr").pluck(:translation_key),
    ).to contain_exactly(
      "greeting",
      "resource_sections.getting_started.title",
      "resource_sections.getting_started.guidelines.label",
      "resource_sections.getting_started.guidelines.description",
    )
  end

  it "preserves overrides and translations shipped in locale files by default" do
    theme.set_field(target: :translations, name: "fr", value: "fr:\n  greeting: Bonjour\n")
    theme.save!
    override =
      ThemeTranslationOverride.create!(
        theme: theme,
        locale: "es",
        translation_key: "greeting",
        value: "Hola",
      )

    DiscourseAi::Translation::ShortTextTranslator.expects(:new).never
    job.execute(theme_id: theme.id)

    expect(override.reload.value).to eq("Hola")
    expect(theme.theme_translation_overrides.where(locale: "fr")).not_to exist
  end

  it "replaces overrides and shipped translations when explicitly requested" do
    theme.set_field(target: :translations, name: "fr", value: "fr:\n  greeting: Bonjour\n")
    theme.save!
    ThemeTranslationOverride.create!(
      theme: theme,
      locale: "es",
      translation_key: "greeting",
      value: "Hola",
    )
    translator = mock
    translator.stubs(:translate).returns("translated")
    DiscourseAi::Translation::ShortTextTranslator.stubs(:new).returns(translator)

    job.execute(theme_id: theme.id, override_existing: true)

    expect(theme.theme_translation_overrides.reload.pluck(:locale, :value)).to contain_exactly(
      %w[fr translated],
      %w[es translated],
    )
  end

  it "preserves a manual translation saved while AI is running" do
    SiteSetting.content_localization_supported_locales = "fr"
    theme_id = theme.id
    translator = Object.new
    translator.define_singleton_method(:translate) do
      ThemeTranslationOverride.create!(
        theme_id: theme_id,
        locale: "fr",
        translation_key: "greeting",
        value: "Manual translation",
      )
      "AI translation"
    end
    DiscourseAi::Translation::ShortTextTranslator.stubs(:new).returns(translator)

    job.execute(theme_id: theme.id)

    expect(theme.theme_translation_overrides.reload.find_by!(locale: "fr").value).to eq(
      "Manual translation",
    )
  end

  it "uses the declared object default language when selected source text is missing" do
    theme.set_field(target: :settings, name: "yaml", value: <<~YAML)
      cards:
        type: objects
        default:
          - translation_key: welcome
            title: Bonjour
        schema:
          name: card
          translations:
            default_locale: fr
          properties:
            translation_key:
              type: string
              required: true
            title:
              type: string
              translatable: true
    YAML
    theme.save!
    SiteSetting.content_localization_supported_locales = "fr|es"
    translator = mock
    translator.stubs(:translate).returns("translated")
    DiscourseAi::Translation::ShortTextTranslator.stubs(:new).returns(translator)

    job.execute(theme_id: theme.id)

    expect(
      theme
        .theme_translation_overrides
        .where(translation_key: "cards.welcome.title")
        .pluck(:locale),
    ).to eq(["es"])
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

      job.execute(theme_id: theme.id, source_locale: "fr", override_existing: true)

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

      job.execute(theme_id: theme.id, source_locale: "fr", override_existing: true)
    end

    it "falls back to en override, then en yaml, when the source locale has neither" do
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
        .with(has_entries(text: "Howdy", target_locale: "es"))
        .returns(translator)

      job.execute(theme_id: theme.id, source_locale: "fr", override_existing: true)
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

      job.execute(theme_id: theme.id, source_locale: "fr", override_existing: true)

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

      job.execute(theme_id: theme.id, source_locale: "fr", override_existing: true)

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

    it "excludes the selected source locale and each field's fallback language" do
      theme.set_field(target: :translations, name: "en", value: <<~YAML)
        en:
          greeting: "Hello"
          farewell: "Goodbye"
      YAML
      theme.save!

      translator = mock
      translator.stubs(:translate).returns("translated")
      DiscourseAi::Translation::ShortTextTranslator.stubs(:new).returns(translator)

      job.execute(theme_id: theme.id, source_locale: "fr", override_existing: true)

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

      expect(greeting_locales).to contain_exactly("en", "es")
      expect(farewell_locales).to contain_exactly("es")
    end
  end
end
