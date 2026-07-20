# frozen_string_literal: true

RSpec.describe ThemeSettingsSerializer do
  fab!(:theme)

  let(:theme_setting) do
    yaml = File.read("#{Rails.root.join("spec/fixtures/theme_settings/objects_settings.yaml")}")
    theme.set_field(target: :settings, name: "yaml", value: yaml)
    theme.save!
    theme.settings
  end

  describe "#objects_schema" do
    it "should include the attribute when theme setting is typed objects" do
      payload = ThemeSettingsSerializer.new(theme_setting[:objects_setting]).as_json

      expect(payload[:theme_settings][:objects_schema][:name]).to eq("section")
    end

    it "includes disallowed groups metadata for group properties" do
      theme.set_field(target: :settings, name: "yaml", value: <<~YAML)
        objects_setting:
          type: objects
          default: []
          schema:
            name: section
            properties:
              group_ids:
                type: groups
                disallowed_groups: "0|1"
      YAML
      theme.save!

      payload = ThemeSettingsSerializer.new(theme.reload.settings[:objects_setting]).as_json

      expect(
        payload[:theme_settings][:objects_schema][:properties][:group_ids][:disallowed_groups],
      ).to eq("0|1")
    end
  end

  describe "#disallowed_groups" do
    it "includes disallowed groups metadata for group list settings" do
      theme.set_field(target: :settings, name: "yaml", value: <<~YAML)
        groups_setting:
          type: list
          list_type: group
          disallowed_groups: "0|1"
          default: "2|3"
      YAML
      theme.save!

      payload = ThemeSettingsSerializer.new(theme.reload.settings[:groups_setting]).as_json

      expect(payload[:theme_settings][:disallowed_groups]).to eq("0|1")
    end
  end

  describe "#valid_values" do
    fab!(:theme_with_enum, :theme)

    before do
      theme_with_enum.set_field(target: :settings, name: "yaml", value: <<~YAML)
          my_enum:
            type: enum
            default: option_a
            choices:
              - option_a
              - option_b
              - option_c
        YAML
      theme_with_enum.save!
    end

    it "returns choice labels from locale files when defined" do
      ThemeField.create!(
        theme_id: theme_with_enum.id,
        name: "en",
        type_id: ThemeField.types[:yaml],
        target_id: Theme.targets[:translations],
        value: <<~YAML,
          en:
            theme_metadata:
              settings:
                my_enum:
                  choices:
                    option_a: "Option A Label"
                    option_b: "Option B Label"
                    option_c: "Option C Label"
        YAML
      )

      payload =
        ThemeSettingsSerializer.new(theme_with_enum.reload.settings[:my_enum]).as_json[
          :theme_settings
        ]

      expect(payload[:valid_values]).to eq(
        [
          { name: "Option A Label", value: "option_a" },
          { name: "Option B Label", value: "option_b" },
          { name: "Option C Label", value: "option_c" },
        ],
      )
    end

    it "returns raw values when no locale labels are defined" do
      payload =
        ThemeSettingsSerializer.new(theme_with_enum.settings[:my_enum]).as_json[:theme_settings]

      expect(payload[:valid_values]).to eq(%w[option_a option_b option_c])
    end

    it "handles mixed case where some choices have labels and some don't" do
      ThemeField.create!(
        theme_id: theme_with_enum.id,
        name: "en",
        type_id: ThemeField.types[:yaml],
        target_id: Theme.targets[:translations],
        value: <<~YAML,
          en:
            theme_metadata:
              settings:
                my_enum:
                  choices:
                    option_a: "Option A Label"
        YAML
      )

      payload =
        ThemeSettingsSerializer.new(theme_with_enum.reload.settings[:my_enum]).as_json[
          :theme_settings
        ]

      expect(payload[:valid_values]).to eq(
        [{ name: "Option A Label", value: "option_a" }, "option_b", "option_c"],
      )
    end

    it "handles integer choice values with string locale keys" do
      theme_with_enum.set_field(target: :settings, name: "yaml", value: <<~YAML)
          int_enum:
            type: enum
            default: 1
            choices:
              - 1
              - 2
              - 3
        YAML
      theme_with_enum.save!

      ThemeField.create!(
        theme_id: theme_with_enum.id,
        name: "en",
        type_id: ThemeField.types[:yaml],
        target_id: Theme.targets[:translations],
        value: <<~YAML,
          en:
            theme_metadata:
              settings:
                int_enum:
                  choices:
                    "1": "One"
                    "2": "Two"
                    "3": "Three"
        YAML
      )

      payload =
        ThemeSettingsSerializer.new(theme_with_enum.reload.settings[:int_enum]).as_json[
          :theme_settings
        ]

      expect(payload[:valid_values]).to eq(
        [{ name: "One", value: 1 }, { name: "Two", value: 2 }, { name: "Three", value: 3 }],
      )
    end
  end
end
