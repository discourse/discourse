# frozen_string_literal: true

describe Theme do
  fab!(:theme)
  let(:key) { "resource_sections.getting_started.links.guidelines.label" }

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
      field.translation_data.dig(
        :ja,
        :resource_sections,
        :getting_started,
        :links,
        :guidelines,
        :label,
      ),
    ).to eq("ガイドライン")
  end

  it "exposes only fields marked translatable" do
    expect(theme.object_translation_defaults.keys).to contain_exactly(
      "resource_sections.getting_started.title",
      "resource_sections.getting_started.links.guidelines.label",
      "resource_sections.getting_started.links.guidelines.description",
    )
  end

  it "discovers nested translatable fields when the parent has no translatable text" do
    schema = YAML.safe_load(theme.settings_field.value)
    schema["resource_sections"]["schema"]["properties"]["title"].delete("translatable")
    theme.set_field(target: :settings, name: "yaml", value: schema.to_yaml)
    theme.save!

    expect(theme.object_translation_defaults.keys).to contain_exactly(
      "resource_sections.getting_started.links.guidelines.label",
      "resource_sections.getting_started.links.guidelines.description",
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
        field.translation_data.dig(
          :ja,
          :resource_sections,
          :getting_started,
          :links,
          :guidelines,
          :label,
        ),
      ).to eq("ガイドライン")
      expect(
        field.translation_data.dig(
          :fr,
          :resource_sections,
          :getting_started,
          :links,
          :guidelines,
          :label,
        ),
      ).to eq("Règles")
    end
  end

  it "cleans up removed keys after invalid settings are fixed, within this component only" do
    other_theme = Fabricate(:theme, component: true)
    other_theme.set_field(target: :settings, name: "yaml", value: theme.settings_field.value)
    other_theme.save!
    retained_key = "resource_sections.getting_started.title"
    I18n.with_locale(:ja) do
      theme.update_translation(key, "ガイドライン")
      theme.update_translation(retained_key, "リソース")
      other_theme.update_translation(key, "別のガイドライン")
    end
    valid_settings = theme.settings_field.value
    theme.set_field(target: :settings, name: "yaml", value: "resource_sections: [")
    theme.save!
    expect(theme.theme_translation_overrides.count).to eq(2)

    schema = YAML.safe_load(valid_settings)
    schema["resource_sections"]["schema"]["properties"]["links"]["schema"]["properties"][
      "label"
    ].delete("translatable")
    theme.reload
    theme.set_field(target: :settings, name: "yaml", value: schema.to_yaml)
    theme.save!

    expect(theme.theme_translation_overrides.pluck(:translation_key)).to contain_exactly(
      retained_key,
    )
    expect(other_theme.theme_translation_overrides.find_by!(translation_key: key).value).to eq(
      "別のガイドライン",
    )
  end

  it "preserves all overrides while a locale file is malformed and cleans up after correction" do
    theme.set_field(target: :translations, name: "fr", value: "fr:\n  greeting: Bonjour\n")
    theme.save!
    I18n.with_locale(:fr) { theme.update_translation("greeting", "Salut") }
    I18n.with_locale(:ja) { theme.update_translation(key, "ガイドライン") }

    theme.set_field(target: :translations, name: "fr", value: "fr: [")
    theme.save!
    theme.update_setting(:resource_sections, [])
    expect(theme.theme_translation_overrides.pluck(:translation_key)).to contain_exactly(
      key,
      "greeting",
    )

    theme.reload
    theme.set_field(target: :translations, name: "fr", value: "fr:\n  greeting: Bonjour\n")
    theme.save!
    expect(theme.theme_translation_overrides.pluck(:translation_key)).to contain_exactly("greeting")
  end

  it "cleans up locale-only themes while preserving declared keys and extra plural forms" do
    theme.set_field(target: :settings, name: "yaml", value: "unrelated: true\n")
    theme.set_field(
      target: :translations,
      name: "en",
      value: "en:\n  items:\n    other: '%{count} items'\n  removed: Old\n",
    )
    theme.set_field(
      target: :translations,
      name: "fr",
      value: "fr:\n  greeting: Bonjour\n  theme_metadata:\n    description: Description\n",
    )
    theme.save!
    ThemeTranslationOverride.create!(
      theme: theme,
      locale: "fr",
      translation_key: "theme_metadata.description",
      value: "Custom description",
    )
    ThemeTranslationOverride.create!(
      theme: theme,
      locale: "ru",
      translation_key: "items.few",
      value: "%{count} предмета",
    )
    theme.reload
    I18n.with_locale(:fr) do
      theme.update_translation("greeting", "Salut")
      theme.update_translation("removed", "Ancien")
    end
    theme.set_field(target: :translations, name: "en", value: "en:\n  items:\n    other: Items\n")
    theme.save!

    expect(theme.theme_translation_overrides.pluck(:translation_key)).to contain_exactly(
      "items.few",
      "greeting",
      "theme_metadata.description",
    )
    expect(theme.theme_translation_overrides.find_by!(translation_key: "items.few").status).to eq(
      "invalid_interpolation_keys",
    )
  end

  it "removes object overrides when corrected settings no longer declare any objects" do
    I18n.with_locale(:ja) { theme.update_translation(key, "ガイドライン") }
    theme.set_field(target: :settings, name: "yaml", value: "resource_sections: [")
    theme.save!
    theme.reload
    theme.set_field(target: :settings, name: "yaml", value: "unrelated: true\n")
    theme.save!

    expect(theme.theme_translation_overrides).to be_empty
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
        field.translation_data.dig(
          :ja,
          :resource_sections,
          :getting_started,
          :links,
          :guidelines,
          :label,
        ),
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

  it "allows a nested identifier matching a translated parent field" do
    objects = theme.settings[:resource_sections].value
    objects[0]["links"][0]["translation_key"] = "title"
    theme.update_setting(:resource_sections, objects)
    expect(theme.object_translation_defaults).to have_key(
      "resource_sections.getting_started.links.title.label",
    )
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

  it "allows correcting saved objects with invalid identifiers" do
    objects = theme.settings[:resource_sections].value
    theme.update_setting(:resource_sections, objects)
    invalid_objects = objects.deep_dup
    invalid_objects[0]["translation_key"] = "Invalid key"
    theme
      .theme_settings
      .find_by!(name: "resource_sections")
      .update_columns(json_value: invalid_objects)
    theme.reload
    theme.update_setting(:resource_sections, objects)
    expect(theme.reload.object_translation_defaults).to have_key(key)
  end

  it "reports invalid shipped identifiers as settings field errors" do
    theme.set_field(
      target: :settings,
      name: "yaml",
      value: theme.settings_field.value.sub("getting_started", "Uppercase"),
    )
    theme.save!
    expect(theme.settings_field.error).to include("resource_sections", "Uppercase")
  end

  ["fr|es", "", 1, ["fr"]].each do |locale|
    it "reports an invalid default locale #{locale.inspect}" do
      schema = YAML.safe_load(theme.settings_field.value)
      schema["resource_sections"]["schema"]["translations"] = { "default_locale" => locale }
      theme.set_field(target: :settings, name: "yaml", value: schema.to_yaml)
      theme.save!
      expect(theme.settings_field.error).to include("default_locale")
    end
  end

  it "allows identifiers shared by separate nested collections" do
    schema = YAML.safe_load(theme.settings_field.value)
    root = schema["resource_sections"]
    root["schema"]["properties"]["buttons"] = root["schema"]["properties"]["links"].deep_dup
    root["default"][0]["buttons"] = root["default"][0]["links"].deep_dup
    theme.set_field(target: :settings, name: "yaml", value: schema.to_yaml)
    theme.save!
    expect(theme.object_translation_defaults.keys).to include(
      "resource_sections.getting_started.links.guidelines.label",
      "resource_sections.getting_started.buttons.guidelines.label",
    )
  end

  it "rebuilds locale assets when shipped object text changes" do
    theme.set_field(
      target: :settings,
      name: "yaml",
      value: theme.settings_field.value.sub("Community guidelines", "Updated guidelines"),
    )
    theme.save!
    expect(theme.locale_fields.first.javascript_cache.content).to include("Updated guidelines")
  end

  it "does not invalidate locale assets when only theme visibility changes" do
    queries = track_sql_queries { theme.update!(user_selectable: !theme.user_selectable) }
    expect(queries.grep(/UPDATE "theme_fields".*"value_baked" = NULL/)).to be_empty
  end
end
