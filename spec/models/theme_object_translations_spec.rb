# frozen_string_literal: true

RSpec.describe Theme do
  fab!(:theme)
  let(:key) { "resource_sections.getting_started.guidelines.label" }

  before do
    theme.set_field(
      target: :settings,
      name: "yaml",
      value: File.read(file_from_fixtures("translatable_objects.yaml", "theme_settings")),
    )
    theme.save!
  end

  it "exposes object defaults through the existing theme translation system without a locale file" do
    entry =
      I18n.with_locale(:ja) { theme.translations.find { |translation| translation.key == key } }
    expect(entry.default).to eq("Community guidelines")
    entry.value = "ガイドライン"
    expect(
      ThemeTranslationOverride.find_by!(theme: theme, locale: "ja", translation_key: key).value,
    ).to eq("ガイドライン")
    expect(
      TranslationOverride.where("translation_key LIKE ?", "js.theme_translations.#{theme.id}.%"),
    ).not_to exist
    field = theme.theme_fields.find_by!(target_id: Theme.targets[:translations], name: "en")
    expect(
      field.translation_data.dig(:ja, :resource_sections, :getting_started, :guidelines, :label),
    ).to eq("ガイドライン")
  end

  it "exposes only fields marked translatable" do
    expect(theme.object_translation_defaults.keys).to contain_exactly(
      "resource_sections.getting_started.title",
      "resource_sections.getting_started.guidelines.label",
      "resource_sections.getting_started.guidelines.description",
    )
  end

  it "discovers nested translatable fields when the parent has no translatable text" do
    schema = YAML.safe_load(theme.settings_field.value)
    schema["resource_sections"]["schema"]["properties"]["title"].delete("translatable")
    theme.set_field(target: :settings, name: "yaml", value: schema.to_yaml)
    theme.save!

    expect(theme.object_translation_defaults.keys).to contain_exactly(
      "resource_sections.getting_started.guidelines.label",
      "resource_sections.getting_started.guidelines.description",
    )
  end

  it "reports a schema error when translatable fields have no identifier property" do
    schema = YAML.safe_load(theme.settings_field.value)
    schema["resource_sections"]["default"] = []
    schema["resource_sections"]["schema"]["properties"].delete("translation_key")
    theme.set_field(target: :settings, name: "yaml", value: schema.to_yaml)
    theme.save!

    expect(theme.settings_field.error).to include(
      I18n.t("themes.settings_errors.translatable_requires_translation_key", schema: "section"),
    )
  end

  ["invalid YAML", "invalid schema"].each do |failure|
    it "preserves translations when saving and correcting #{failure}" do
      valid_settings = theme.settings_field.value
      invalid_settings =
        if failure == "invalid YAML"
          "resource_sections: ["
        else
          schema = YAML.safe_load(valid_settings)
          schema["resource_sections"]["schema"]["properties"]["title"]["type"] = "integer"
          schema.to_yaml
        end
      { ja: "ガイドライン", fr: "Règles" }.each do |locale, text|
        I18n.with_locale(locale) { theme.update_translation(key, text) }
      end
      overrides =
        theme
          .theme_translation_overrides
          .reload
          .order(:id)
          .pluck(:id, :locale, :value, :original_translation)

      theme.set_field(target: :settings, name: "yaml", value: invalid_settings)
      theme.save!

      expect(theme.settings_field.error).to be_present
      expect(theme.settings).to be_empty
      expect(
        theme
          .theme_translation_overrides
          .reload
          .order(:id)
          .pluck(:id, :locale, :value, :original_translation),
      ).to eq(overrides)

      theme.set_field(target: :settings, name: "yaml", value: valid_settings)
      theme.save!

      expect(theme.settings_field.error).to be_blank
      expect(
        theme
          .theme_translation_overrides
          .reload
          .order(:id)
          .pluck(:id, :locale, :value, :original_translation),
      ).to eq(overrides)
      field = theme.theme_fields.find_by!(target_id: Theme.targets[:translations], name: "en")
      expect(
        field.translation_data.dig(:ja, :resource_sections, :getting_started, :guidelines, :label),
      ).to eq("ガイドライン")
      expect(
        field.translation_data.dig(:fr, :resource_sections, :getting_started, :guidelines, :label),
      ).to eq("Règles")
    end
  end

  it "removes a field's overrides when it is no longer translatable" do
    I18n.with_locale(:ja) { theme.update_translation(key, "ガイドライン") }
    schema = YAML.safe_load(theme.settings_field.value)
    schema["resource_sections"]["schema"]["properties"]["links"]["schema"]["properties"]["label"][
      "translatable"
    ] = false

    theme.set_field(target: :settings, name: "yaml", value: schema.to_yaml)
    theme.save!

    expect(theme.object_translation_defaults).not_to have_key(key)
    expect(ThemeTranslationOverride.where(theme: theme, translation_key: key)).not_to exist
  end

  it "rejects translatable properties that are not strings even without objects" do
    schema = YAML.safe_load(theme.settings_field.value)
    schema["resource_sections"]["default"] = []
    schema["resource_sections"]["schema"]["properties"]["title"]["type"] = "integer"
    theme.set_field(target: :settings, name: "yaml", value: schema.to_yaml)

    theme.save!
    expect(theme.settings_field.error).to include(
      I18n.t("themes.settings_errors.translatable_requires_string", property: "title"),
    )
  end

  it "marks changed defaults outdated, refreshes assets, and retires removed object translations" do
    I18n.with_locale(:fr) { theme.update_translation(key, "Règles") }
    field = theme.theme_fields.find_by!(target_id: Theme.targets[:translations], name: "en")
    field.ensure_baked!
    old_content = field.reload.javascript_cache.content
    objects = theme.settings[:resource_sections].value
    objects[0]["links"][0]["label"] = "Read our guidelines"
    theme.update_setting(:resource_sections, objects)
    override = ThemeTranslationOverride.find_by!(theme: theme, translation_key: key)
    expect(override.status).to eq("outdated")
    field.reload.ensure_baked!
    expect(field.reload.javascript_cache.content).not_to eq(old_content)
    objects[0]["links"] = []
    theme.update_setting(:resource_sections, objects)
    expect(ThemeTranslationOverride.where(theme: theme, translation_key: key)).not_to exist
  end

  %w[en fr].each do |locale|
    it "reports malformed #{locale} locale files as field errors and recovers after correction" do
      I18n.with_locale(:ja) { theme.update_translation(key, "ガイドライン") }
      override = ThemeTranslationOverride.find_by!(theme: theme, locale: "ja", translation_key: key)
      theme.set_field(target: :translations, name: locale, value: "#{locale}: [")

      theme.save!

      field = theme.theme_fields.find_by!(target_id: Theme.targets[:translations], name: locale)
      expect(field.error).to be_present
      expect(field.value).to eq("#{locale}: [")
      expect(override.reload.value).to eq("ガイドライン")

      theme.reload
      theme.set_field(target: :translations, name: locale, value: "#{locale}: {}")
      theme.save!

      expect(field.reload.error).to be_blank
      expect(
        field.translation_data.dig(:ja, :resource_sections, :getting_started, :guidelines, :label),
      ).to eq("ガイドライン")
      expect(override.reload.value).to eq("ガイドライン")
    end
  end

  it "rejects colliding locale-file namespaces when saving settings" do
    theme.set_field(
      target: :translations,
      name: "en",
      value: "en:\n  resource_sections: Reserved\n",
    ).save!
    expect {
      theme.update_setting(:resource_sections, theme.settings[:resource_sections].value)
    }.to raise_error(Discourse::InvalidParameters, /resource_sections/)
  end

  it "uses declared default languages and isolates duplicate components" do
    theme.set_field(
      target: :settings,
      name: "yaml",
      value:
        theme.settings_field.value.sub(
          "    name: section",
          "    name: section\n    translations:\n      default_locale: fr",
        ),
    )
    theme.save!
    other = Fabricate(:theme)
    other.set_field(target: :settings, name: "yaml", value: theme.settings_field.value)
    other.save!
    entry =
      I18n.with_locale(:ja) { theme.translations.find { |translation| translation.key == key } }
    expect(entry.default_locale).to eq("fr")
    entry.value = "ガイドライン"
    expect(
      I18n.with_locale(:ja) do
        other.translations.find { |translation| translation.key == key }.value
      end,
    ).to eq("Community guidelines")
  end

  it "rejects invalid identifier characters without saving the setting" do
    objects = theme.settings[:resource_sections].value
    [
      "Welcome",
      "1welcome",
      "_welcome",
      "welcome-home",
      "welcome home",
      "welcome.home",
      "welcôme",
    ].each do |identifier|
      objects[0]["translation_key"] = identifier
      expect { theme.update_setting(:resource_sections, objects) }.to raise_error(
        Discourse::InvalidParameters,
      )
      expect(theme.reload.settings[:resource_sections].value[0]["translation_key"]).to eq(
        "getting_started",
      )
    end
  end

  it "rejects duplicate identifiers and rolls back the setting" do
    objects = theme.settings[:resource_sections].value
    objects[0]["links"] << objects[0]["links"][0].dup
    expect { theme.update_setting(:resource_sections, objects) }.to raise_error(
      Discourse::InvalidParameters,
    )
    expect(theme.reload.settings[:resource_sections].value[0]["links"].size).to eq(1)
  end

  it "removes overrides when the translation declaration is removed" do
    I18n.with_locale(:fr) { theme.update_translation(key, "Règles") }
    theme.set_field(target: :settings, name: "yaml", value: "other: value")
    theme.save!
    expect(ThemeTranslationOverride.where(theme: theme)).not_to exist
  end

  it "rejects a nested identifier matching a translated parent field without saving" do
    objects = theme.settings[:resource_sections].value
    objects[0]["links"][0]["translation_key"] = "title"
    expect { theme.update_setting(:resource_sections, objects) }.to raise_error(
      Discourse::InvalidParameters,
      /title/,
    )
    expect(theme.reload.settings[:resource_sections].value[0]["links"][0]["translation_key"]).to eq(
      "guidelines",
    )
    expect(
      theme.locale_fields.first.translation_data.dig(
        :en,
        :resource_sections,
        :getting_started,
        :title,
      ),
    ).to eq("Resources")
  end

  it "preserves translations through clearing, restoring, daily checks, and asset rebuilds" do
    I18n.with_locale(:ja) { theme.update_translation(key, "ガイドライン") }
    override = ThemeTranslationOverride.find_by!(theme: theme, locale: "ja", translation_key: key)
    objects = theme.settings[:resource_sections].value
    objects[0]["links"][0]["label"] = ""
    theme.update_setting(:resource_sections, objects)
    expect(override.reload.value).to eq("ガイドライン")
    expect(override.status).to eq("outdated")
    expect(theme.object_translation_defaults.dig(key, :text)).to eq("")

    objects[0]["links"][0]["label"] = "Community guidelines"
    theme.update_setting(:resource_sections, objects)
    2.times { Jobs::CheckTranslationOverrides.new.execute({}) }
    theme.reload.save!
    field = theme.reload.locale_fields.first
    field.invalidate_baked!
    field.ensure_baked!
    expect(override.reload.value).to eq("ガイドライン")
    expect(override.status).to eq("up_to_date")
    expect(field.javascript_cache.content).to include("ガイドライン")

    objects[0]["links"][0]["label"] = ""
    theme.update_setting(:resource_sections, objects)
    objects[0]["links"] = []
    theme.update_setting(:resource_sections, objects)
    expect(ThemeTranslationOverride.where(id: override.id)).not_to exist
  end
end
