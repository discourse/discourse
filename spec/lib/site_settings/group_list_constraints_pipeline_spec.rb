# frozen_string_literal: true

class GroupListConstraintsPipelineValidator
  def initialize(_opts)
  end

  def valid_value?(value)
    value.to_s.split("|").exclude?("14")
  end

  def error_message
    "trust level 4 is rejected by the custom validator"
  end
end

RSpec.describe SiteSettingExtension do
  describe "group list constraints pipeline" do
    let(:provider) { SiteSettings::LocalProcessProvider.new }
    let(:settings) { new_settings(provider) }

    it "normalizes constraints and legacy declarations identically on assignment and in storage" do
      settings.setting(
        :pipeline_constraints,
        "1|14",
        type: :group_list,
        constraints: {
          mandatory: %i[admins],
          disallowed: %i[anonymous_users],
        },
      )
      settings.setting(
        :pipeline_legacy,
        "1|14",
        type: :group_list,
        mandatory_values: "1",
        disallowed_groups: "4",
      )

      settings.pipeline_constraints = "14|4"
      settings.pipeline_legacy = "14|4"

      expect(
        [
          settings.pipeline_constraints,
          provider.find(:pipeline_constraints).value,
          settings.pipeline_legacy,
          provider.find(:pipeline_legacy).value,
        ],
      ).to eq(%w[1|14 1|14 1|14 1|14])
    end

    it "resolves and normalizes symbolic group names in defaults" do
      settings.setting(
        :pipeline_symbolic_default,
        "admins|trust_level_4",
        type: :group_list,
        constraints: {
          mandatory: %i[admins],
        },
      )

      expect(
        [settings.defaults[:pipeline_symbolic_default], settings.pipeline_symbolic_default],
      ).to eq(%w[1|14 1|14])
    end

    it "returns a fully normalized group list directly from type supervisor to_db_value" do
      settings.setting(
        :pipeline_to_db_value,
        "1",
        type: :group_list,
        constraints: {
          mandatory: %i[admins],
          disallowed: %i[anonymous_users],
        },
      )

      expect(settings.type_supervisor.to_db_value(:pipeline_to_db_value, "14|4")).to eq(
        ["1|14", SiteSetting.types[:group_list]],
      )
    end

    it "deduplicates mandatory ids and emits the normalized assigned value" do
      settings.setting(
        :pipeline_no_duplicates,
        "1",
        type: :group_list,
        constraints: {
          mandatory: %i[admins],
          disallowed: %i[anonymous_users],
        },
      )
      settings.refresh!

      event =
        DiscourseEvent.track(:site_setting_changed) { settings.pipeline_no_duplicates = "1|4|1|14" }

      expect(
        [
          settings.pipeline_no_duplicates,
          provider.find(:pipeline_no_duplicates).value,
          event[:params],
        ],
      ).to eq(["1|14", "1|14", [:pipeline_no_duplicates, "1", "1|14"]])
    end

    it "normalizes a stored row through the getter after a disallowed rule is introduced" do
      provider.save(:pipeline_legacy_disallowed_row, "1|4", SiteSetting.types[:group_list])
      settings.setting(
        :pipeline_legacy_disallowed_row,
        "1",
        type: :group_list,
        constraints: {
          disallowed: %i[anonymous_users],
        },
      )
      settings.refresh!

      expect(settings.pipeline_legacy_disallowed_row).to eq("1")
    end

    it "does not report a stored row as overridden when mandatory normalization matches the default" do
      provider.save(:pipeline_legacy_mandatory_row, "14", SiteSetting.types[:group_list])
      settings.setting(
        :pipeline_legacy_mandatory_row,
        "1|14",
        type: :group_list,
        constraints: {
          mandatory: %i[admins],
        },
      )
      settings.refresh!

      expect(
        [
          settings.modified,
          settings.all_settings(only_overridden: true, include_locale_setting: false),
        ],
      ).to eq([{}, []])
    end

    it "rejects an assignment that at_least_one normalization makes empty" do
      settings.setting(
        :pipeline_at_least_one,
        "14",
        type: :group_list,
        constraints: {
          at_least_one: true,
          disallowed: %i[admins],
        },
      )

      expect { settings.pipeline_at_least_one = "1" }.to raise_error(
        Discourse::InvalidParameters,
        /pipeline_at_least_one/,
      )
    end

    it "rejects a symbolic token in a saved group list" do
      settings.setting(:pipeline_symbolic_assignment, "", type: :group_list, constraints: {})

      expect { settings.pipeline_symbolic_assignment = "admins" }.to raise_error(
        Discourse::InvalidParameters,
        /admins/,
      )
    end

    it "rejects a saved group id that does not exist" do
      missing_group_id = Group.maximum(:id).to_i + 1000
      settings.setting(
        :pipeline_missing_group,
        "1",
        type: :group_list,
        constraints: {
          at_least_one: true,
        },
      )

      expect { settings.pipeline_missing_group = missing_group_id.to_s }.to raise_error(
        Discourse::InvalidParameters,
        /#{missing_group_id}/,
      )
    end

    it "rejects an unknown constraints key while defining a setting" do
      expect do
        settings.setting(
          :pipeline_unknown_key,
          "1",
          type: :group_list,
          constraints: {
            manditory: %i[admins],
          },
        )
      end.to raise_error(Discourse::InvalidParameters, /manditory/)
    end

    it "rejects an unknown group name in constraints while defining a setting" do
      expect do
        settings.setting(
          :pipeline_unknown_group,
          "1",
          type: :group_list,
          constraints: {
            mandatory: %i[adminz],
          },
        )
      end.to raise_error(Discourse::InvalidParameters, /adminz/)
    end

    it "rejects a group declared as both mandatory and disallowed" do
      expect do
        settings.setting(
          :pipeline_conflicting_group,
          "1",
          type: :group_list,
          constraints: {
            mandatory: %i[admins],
            disallowed: %i[admins],
          },
        )
      end.to raise_error(Discourse::InvalidParameters, /both mandatory and disallowed/)
    end

    it "warns and keeps legacy rules when production discards a bad constraints block" do
      production = ActiveSupport::EnvironmentInquirer.new("production")
      allow(Rails).to receive(:env).and_return(production)
      allow(Discourse).to receive(:warn_exception)

      expect do
        settings.setting(
          :pipeline_production_degradation,
          "1",
          type: :group_list,
          mandatory_values: "1",
          constraints: {
            disallowed: %i[anonymous_users],
          },
        )
      end.not_to raise_error

      settings.pipeline_production_degradation = "4|14"

      expect(
        [
          settings.pipeline_production_degradation,
          provider.find(:pipeline_production_degradation).value,
        ],
      ).to eq(%w[1|4|14 1|4|14])
      expect(Discourse).to have_received(:warn_exception)
    end

    it "uses the normalized db value as the theme service ruby value" do
      # Defined on the real SiteSetting because the service reads it there; the
      # `ensure` block below unregisters it so it cannot leak into other examples.
      SiteSetting.send(
        :setting,
        :pipeline_theme_groups,
        "1",
        type: :group_list,
        themeable: true,
        constraints: {
          mandatory: %i[admins],
        },
      )
      SiteSetting.refresh!
      admin = Fabricate(:admin)
      theme = Fabricate(:theme)

      result =
        Themes::ThemeSiteSettingManager.call(
          guardian: admin.guardian,
          params: {
            theme_id: theme.id,
            name: :pipeline_theme_groups,
            value: "14",
          },
        )

      expect(result).to run_successfully
      expect(
        [
          result.setting_db_value,
          result.setting_ruby_value,
          result.theme_site_setting.value,
          SiteSetting.pipeline_theme_groups(theme_id: theme.id),
        ],
      ).to eq(%w[1|14 1|14 1|14 1|14])
    ensure
      SiteSetting.themeable.delete(:pipeline_theme_groups)
      SiteSetting.mandatory_values.delete(:pipeline_theme_groups)
      SiteSetting
        .defaults
        .instance_variable_get(:@defaults)
        .each { |_, defaults| defaults.delete(:pipeline_theme_groups) }
      SiteSetting.refresh!
    end

    it "keeps reserved_usernames mandatory list values and metadata unchanged" do
      mandatory_values = SiteSetting.mandatory_values[:reserved_usernames]
      submitted_value = "pipeline-unique-username"
      expected_value = (mandatory_values.split("|") | [submitted_value]).join("|")

      SiteSetting.reserved_usernames = submitted_value

      expect(
        [
          SiteSetting.reserved_usernames,
          SiteSetting.provider.find(:reserved_usernames).value,
          SiteSetting.mandatory_values[:reserved_usernames],
        ],
      ).to eq([expected_value, expected_value, mandatory_values])
    end

    it "keeps legacy group list wire metadata as derived pipe strings" do
      settings.setting(
        :pipeline_legacy_wire_metadata,
        "1|2",
        type: :group_list,
        mandatory_values: "1|2",
        disallowed_groups: "4|5",
      )

      setting =
        settings
          .all_settings(include_locale_setting: false)
          .find { |candidate| candidate[:setting] == :pipeline_legacy_wire_metadata }

      expect(setting.values_at(:mandatory_values, :disallowed_groups)).to eq(%w[1|2 4|5])
    end

    it "exposes constraints group list wire metadata as derived pipe strings" do
      settings.setting(
        :pipeline_constraints_wire_metadata,
        "1|2",
        type: :group_list,
        constraints: {
          mandatory: %i[admins moderators],
          disallowed: %i[anonymous_users logged_in_users],
        },
      )

      setting =
        settings
          .all_settings(include_locale_setting: false)
          .find { |candidate| candidate[:setting] == :pipeline_constraints_wire_metadata }

      expect(setting.values_at(:mandatory_values, :disallowed_groups)).to eq(%w[1|2 4|5])
    end

    it "continues to run a custom validator declared on a group list" do
      settings.setting(
        :pipeline_custom_validator,
        "1",
        type: :group_list,
        constraints: {
        },
        validator: "GroupListConstraintsPipelineValidator",
      )

      expect { settings.pipeline_custom_validator = "14" }.to raise_error(
        Discourse::InvalidParameters,
        /custom validator/,
      )
    end
  end
end
