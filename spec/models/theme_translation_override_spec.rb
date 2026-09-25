# frozen_string_literal: true

RSpec.describe ThemeTranslationOverride do
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
end
