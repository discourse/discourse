# frozen_string_literal: true

describe ThemeTranslationOverride do
  fab!(:theme)

  it "uses an exact English key even when its name matches a plural form" do
    theme.set_field(
      target: :translations,
      name: "en",
      value: { en: { labels: { few: "A few", other: "Other" } } }.deep_stringify_keys.to_yaml,
    )
    theme.save!
    I18n.with_locale(:fr) { theme.update_translation("labels.few", "Quelques-uns") }

    override =
      theme.theme_translation_overrides.find_by!(locale: "fr", translation_key: "labels.few")
    expect(override.original_translation).to eq("A few")
    expect(override.status).to eq("up_to_date")
  end

  it "tracks and validates plural forms absent from English using the other form" do
    theme.set_field(
      target: :translations,
      name: "en",
      value: {
        en: {
          items: {
            one: "%{count} item",
            other: "%{count} items",
          },
        },
      }.deep_stringify_keys.to_yaml,
    )
    theme.set_field(
      target: :translations,
      name: "ru",
      value: { ru: { items: { few: "%{count} предмета" } } }.deep_stringify_keys.to_yaml,
    )
    theme.save!
    I18n.with_locale(:ru) { theme.update_translation("items.few", "%{count} вещи") }
    override =
      theme.theme_translation_overrides.find_by!(locale: "ru", translation_key: "items.few")

    expect(override.original_translation).to eq("%{count} items")
    expect(override.status).to eq("up_to_date")

    I18n.with_locale(:en) { theme.update_translation("items.other", "%{count} resources") }
    override.reload
    expect(override.status).to eq("outdated")
    expect(override.make_up_to_date!).to eq(true)
    expect(override.reload.status).to eq("up_to_date")
    expect { override.update!(value: "%{unknown} вещи") }.to raise_error(
      ActiveRecord::RecordInvalid,
    )
  end

  it "handles a localized nested key when English contains a scalar" do
    theme.set_field(target: :translations, name: "en", value: "en:\n  menu: Menu\n")
    theme.set_field(
      target: :translations,
      name: "fr",
      value: "fr:\n  menu:\n    label: Menu français\n",
    )
    theme.save!
    entries = ThemeTranslationManager.search_site_texts("", locale: :fr, theme: theme)
    expect(entries).to include(include(default_text: "Menu français", default_locale: "fr"))
  end

  it "tracks the shipped default for a key found only in the selected locale" do
    theme.set_field(target: :translations, name: "en", value: "en: {}")
    theme.set_field(target: :translations, name: "fr", value: "fr:\n  special: Bonjour\n")
    theme.save!
    I18n.with_locale(:fr) { theme.update_translation("special", "Salut") }
    record = theme.theme_translation_overrides.find_by!(locale: "fr", translation_key: "special")
    expect(record.original_translation).to eq("Bonjour")
    record.update_columns(original_translation: "Old")
    expect(record.make_up_to_date!).to eq(true)
    expect(record.reload.status).to eq("up_to_date")
  end

  it "allows shipped placeholders when the source override omits them" do
    theme.set_field(target: :translations, name: "en", value: "en:\n  greeting: Hello %{name}\n")
    theme.save!
    I18n.with_locale(:en) { theme.update_translation("greeting", "Hello") }
    I18n.with_locale(:fr) { theme.update_translation("greeting", "Bonjour %{name}") }
    record = theme.theme_translation_overrides.find_by!(locale: "fr", translation_key: "greeting")
    expect(record.status).to eq("up_to_date")
    entry =
      ThemeTranslationManager.find_site_text(
        "js.theme_translations.#{theme.id}.greeting",
        locale: :fr,
      )
    expect(entry.site_text[:interpolation_keys]).to eq(["name"])
  end

  it "lets admins acknowledge an unknown baseline without changing the text" do
    theme.set_field(target: :translations, name: "en", value: "en:\n  greeting: Hello\n")
    theme.save!
    I18n.with_locale(:fr) { theme.update_translation("greeting", "Bonjour") }
    record = theme.theme_translation_overrides.find_by!(locale: "fr", translation_key: "greeting")
    record.update_columns(original_translation: nil)
    expect(record.status).to eq("unknown")
    expect(record.make_up_to_date!).to eq(true)
    expect(record.reload.status).to eq("up_to_date")
    expect(record.value).to eq("Bonjour")
  end
end
