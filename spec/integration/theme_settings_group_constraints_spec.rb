# frozen_string_literal: true

RSpec.describe "Theme group list constraints" do
  fab!(:theme)

  # Installs `yaml` as the theme's settings field and returns the field, so an
  # example can assert either on the parsed settings or on the field error.
  def set_settings(yaml)
    field = theme.set_field(target: :settings, name: "yaml", value: yaml)
    theme.save!
    field.ensure_baked!
    field
  end

  # Parses `yaml` without going through the theme, so an example can assert on the
  # options the parser hands to ThemeSettingsManager.
  def parse(yaml)
    field = ThemeField.create!(theme_id: -1, target_id: 3, name: "yaml", value: yaml)
    parsed = {}
    ThemeSettingsParser
      .new(field)
      .load { |name, default, type, opts| parsed[name] = { default:, type:, opts: } }
    parsed
  end

  describe "the settings parser" do
    it "compiles a constraints block into a constraints object and the derived wire strings" do
      parsed = parse(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "admins|trust_level_4"
          constraints:
            at_least_one: true
            mandatory: [admins]
            disallowed: [anonymous_users]
      YAML
      opts = parsed[:groups_setting][:opts]

      expect(opts[:constraints]).to be_a(SiteSettings::GroupListConstraints)
      expect(opts[:constraints].at_least_one).to eq(true)
      expect(opts[:constraints].mandatory_ids).to eq([1])
      expect(opts[:constraints].disallowed_ids).to eq([4])
      expect(opts[:mandatory_values]).to eq("1")
      expect(opts[:disallowed_groups]).to eq("4")
    end

    it "keeps compiling the legacy disallowed_groups key into the same object" do
      parsed = parse(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          disallowed_groups: "0|1"
          default: "2|3"
      YAML
      opts = parsed[:groups_setting][:opts]

      expect(opts[:disallowed_groups]).to eq("0|1")
      expect(opts[:constraints].disallowed_ids).to eq([0, 1])
    end

    it "resolves symbolic group names in the default" do
      parsed = parse(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "admins|trust_level_4"
      YAML

      expect(parsed[:groups_setting][:default]).to eq("1|14")
    end

    it "leaves settings that are not group lists alone" do
      parsed = parse(<<~YAML)
        plain_list_setting:
          type: list
          default: "one|two"
      YAML
      opts = parsed[:plain_list_setting][:opts]

      expect(opts[:constraints]).to be_nil
      expect(parsed[:plain_list_setting][:default]).to eq("one|two")
    end
  end

  describe "schema errors in theme yaml" do
    it "wraps a schema error in the translated theme settings error" do
      field = set_settings(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "1"
          constraints:
            mandatory: [adminz]
      YAML
      envelope =
        I18n.t(
          "themes.settings_errors.group_constraints_not_valid",
          name: "groups_setting",
          error_messages: "",
        ).strip

      expect(field.error).to start_with(envelope)
      expect(field.error).to include("adminz")
    end

    it "reports at_least_one on an objects property through its own translation" do
      field = set_settings(<<~YAML)
        objects_setting:
          type: objects
          default: []
          schema:
            name: section
            properties:
              group_ids:
                type: groups
                constraints:
                  at_least_one: true
      YAML

      expect(field.error).to eq(
        I18n.t(
          "themes.settings_errors.group_at_least_one_not_supported",
          property: "objects_setting schema property group_ids",
        ),
      )
    end

    it "reports an unknown constraints key as a field error" do
      field = set_settings(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "1"
          constraints:
            manditory: [admins]
      YAML

      expect(field.error).to include("manditory")
      expect(theme.reload.settings).to eq({})
    end

    it "reports an unknown group name as a field error" do
      field = set_settings(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "1"
          constraints:
            mandatory: [adminz]
      YAML

      expect(field.error).to include("adminz")
    end

    it "reports a default that violates the declared rules as a field error" do
      field = set_settings(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "trust_level_4"
          constraints:
            mandatory: [admins]
      YAML

      expect(field.error).to include("groups_setting")
    end

    it "reports at_least_one on an objects groups property, pointing at the min validation" do
      field = set_settings(<<~YAML)
        objects_setting:
          type: objects
          default: []
          schema:
            name: section
            properties:
              group_ids:
                type: groups
                constraints:
                  at_least_one: true
      YAML

      expect(field.error).to include("min")
    end

    it "keeps a valid theme free of errors" do
      field = set_settings(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "admins|trust_level_4"
          constraints:
            mandatory: [admins]
            disallowed: [anonymous_users]
      YAML

      expect(field.error).to be_nil
    end
  end

  describe "the marshalled type info" do
    it "carries the derived wire strings but not the constraints object" do
      set_settings(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "admins"
          constraints:
            mandatory: [admins]
            disallowed: [anonymous_users]
      YAML
      type_info = theme.reload.build_theme_setting_type_info_hash[:groups_setting]

      expect(type_info).not_to have_key(:constraints)
      expect(type_info[:mandatory_values]).to eq("1")
      expect(type_info[:disallowed_groups]).to eq("4")
      expect { Marshal.dump(type_info) }.not_to raise_error
    end

    it "keeps the compiled rules out of an objects schema, at any depth" do
      set_settings(<<~YAML)
        objects_setting:
          type: objects
          default: []
          schema:
            name: section
            properties:
              group_ids:
                type: groups
                constraints:
                  disallowed: [anonymous_users]
              links:
                type: objects
                schema:
                  name: link
                  properties:
                    group_ids:
                      type: groups
                      constraints:
                        mandatory: [admins]
      YAML
      setting = theme.reload.settings[:objects_setting]
      payload = ThemeSettingsSerializer.new(setting).as_json[:theme_settings]
      property = payload[:objects_schema][:properties][:group_ids]

      expect(property[:disallowed_groups]).to eq("4")
      expect(payload[:objects_schema].to_json).not_to include("mandatory_ids")
      expect(theme.build_theme_setting_type_info_hash.to_json).not_to include("mandatory_ids")
    end
  end

  describe "a group list theme setting" do
    let(:groups_yaml) { <<~YAML }
        groups_setting:
          type: list
          list_type: group
          default: "admins"
          constraints:
            mandatory: [admins]
            disallowed: [anonymous_users]
      YAML

    it "adds mandatory ids first and strips disallowed ids when saving" do
      set_settings(groups_yaml)

      theme.settings[:groups_setting].value = "14|4"

      expect(theme.reload.settings[:groups_setting].value).to eq("1|14")
    end

    it "projects the rules onto a row stored before they were declared" do
      set_settings(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "14"
      YAML
      theme.settings[:groups_setting].value = "14|4"
      set_settings(groups_yaml)

      expect(theme.reload.settings[:groups_setting].value).to eq("1|14")
    end

    it "applies the rules before the everyone display alias" do
      SiteSetting.granular_anonymous_and_logged_in_groups_permissions = true
      set_settings(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "1"
      YAML
      theme.settings[:groups_setting].value = "0|1"
      set_settings(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "1"
          constraints:
            disallowed: [0]
      YAML

      # If the alias ran first, the stored 0 would become 5 and survive the rule.
      expect(theme.reload.settings[:groups_setting].value).to eq("1")
    end

    it "rejects an assignment that at_least_one normalization makes empty" do
      set_settings(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "trust_level_4"
          constraints:
            at_least_one: true
            disallowed: [admins]
      YAML

      expect { theme.settings[:groups_setting].value = "1" }.to raise_error(
        Discourse::InvalidParameters,
      )
    end

    it "rejects an assignment naming a group that does not exist" do
      set_settings(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "1"
      YAML
      missing_group_id = Group.maximum(:id).to_i + 1000

      expect { theme.settings[:groups_setting].value = missing_group_id.to_s }.to raise_error(
        Discourse::InvalidParameters,
        /#{missing_group_id}/,
      )
    end
  end

  describe "groups properties inside an objects setting" do
    let(:objects_yaml) { <<~YAML }
        objects_setting:
          type: objects
          default: []
          schema:
            name: section
            properties:
              group_ids:
                type: groups
                constraints:
                  mandatory: [admins]
                  disallowed: [anonymous_users]
              links:
                type: objects
                schema:
                  name: link
                  properties:
                    group_ids:
                      type: groups
                      constraints:
                        disallowed: [trust_level_0]
      YAML

    it "applies the rules to nested groups properties when saving" do
      set_settings(objects_yaml)

      theme.settings[:objects_setting].value = [
        {
          "group_ids" => [Group::AUTO_GROUPS[:anonymous_users], Group::AUTO_GROUPS[:trust_level_4]],
          "links" => [
            {
              "group_ids" => [
                Group::AUTO_GROUPS[:trust_level_0],
                Group::AUTO_GROUPS[:trust_level_1],
              ],
            },
          ],
        },
      ]

      expect(theme.reload.settings[:objects_setting].value).to eq(
        [
          {
            "group_ids" => [Group::AUTO_GROUPS[:admins], Group::AUTO_GROUPS[:trust_level_4]],
            "links" => [{ "group_ids" => [Group::AUTO_GROUPS[:trust_level_1]] }],
          },
        ],
      )
    end

    it "projects the rules onto objects stored before they were declared" do
      set_settings(<<~YAML)
        objects_setting:
          type: objects
          default: []
          schema:
            name: section
            properties:
              group_ids:
                type: groups
      YAML
      theme.settings[:objects_setting].value = [
        { "group_ids" => [Group::AUTO_GROUPS[:anonymous_users], Group::AUTO_GROUPS[:staff]] },
      ]
      set_settings(objects_yaml)

      expect(theme.reload.settings[:objects_setting].value.first["group_ids"]).to eq(
        [Group::AUTO_GROUPS[:admins], Group::AUTO_GROUPS[:staff]],
      )
    end
  end

  describe "the theme settings serializer" do
    it "exposes the derived wire strings for a group list" do
      set_settings(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "admins"
          constraints:
            mandatory: [admins]
            disallowed: [anonymous_users]
      YAML
      payload =
        ThemeSettingsSerializer.new(theme.reload.settings[:groups_setting]).as_json[:theme_settings]

      expect(payload[:mandatory_values]).to eq("1")
      expect(payload[:disallowed_groups]).to eq("4")
    end

    it "omits mandatory_values when no mandatory rule is declared" do
      set_settings(<<~YAML)
        groups_setting:
          type: list
          list_type: group
          default: "1"
      YAML
      payload =
        ThemeSettingsSerializer.new(theme.reload.settings[:groups_setting]).as_json[:theme_settings]

      expect(payload).not_to have_key(:mandatory_values)
    end
  end
end
