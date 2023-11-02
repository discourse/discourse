# frozen_string_literal: true

Fabricator(:theme_field) do
  theme
  target_id { 0 }
  name { sequence(:name) { |i| "scss_#{i + 1}" } }
  value { ".test {color: blue;}" }
  error { nil }
end

Fabricator(:migration_theme_field, from: :theme_field) do
  transient :version
  type_id ThemeField.types[:js]
  target_id Theme.targets[:migrations]
  name do |attrs|
    version = attrs[:version] || sequence("theme_#{attrs[:theme].id}_migration_field", 1)
    "#{version.to_s.rjust(4, "0")}-some-name"
  end
  value <<~JS
    export default function migrate(settings) {
      return settings;
    }
  JS
end

Fabricator(:settings_theme_field, from: :theme_field) do
  type_id ThemeField.types[:yaml]
  target_id Theme.targets[:settings]
  name "yaml"
end
