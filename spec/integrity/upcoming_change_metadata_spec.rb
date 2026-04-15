# frozen_string_literal: true

def upcoming_change_setting_files
  [
    File.join(Rails.root, "config", "site_settings.yml"),
    *Dir["#{Rails.root}/plugins/*/config/settings.yml"].sort,
  ]
end

def each_upcoming_change_setting
  upcoming_change_setting_files.each do |file|
    SiteSettings::YamlLoader
      .new(file)
      .load do |category, setting_name, default, opts|
        next if opts[:upcoming_change].blank?

        setting = {
          file: file.delete_prefix("#{Rails.root}/"),
          setting_name: setting_name,
          default: default,
          options: opts,
          upcoming_change: opts[:upcoming_change],
        }

        yield setting
      end
  end
end

def upcoming_change_setting_label(setting)
  "#{setting[:setting_name]} in #{setting[:file]}"
end

def valid_upcoming_change_impact_types
  %w[feature other site_setting_default]
end

def valid_upcoming_change_impact_roles
  %w[staff admins moderators all_members developers]
end

RSpec.describe "upcoming change metadata integrity checks" do
  each_upcoming_change_setting do |setting|
    label = upcoming_change_setting_label(setting)

    it "#{label} is valid" do
      metadata = setting[:upcoming_change]
      allowed_keys = %i[status impact learn_more_url disallow_enabled_for_groups]
      required_keys = %i[status impact]
      unsupported_keys = metadata.keys - allowed_keys
      missing_keys = required_keys - metadata.keys
      valid_statuses = UpcomingChanges.statuses.keys
      status = metadata[:status].to_sym
      impact = metadata[:impact]
      impact_parts = impact.is_a?(String) ? impact.split(",") : []

      aggregate_failures do
        expect(setting[:options][:hidden]).to eq(true), "#{label} must set `hidden: true`"
        expect(setting[:options][:client]).to eq(true), "#{label} must set `client: true`"
        expect(setting[:default]).to eq(false), "#{label} must set `default: false`"

        expect(unsupported_keys).to be_empty,
        "#{label} has unsupported upcoming_change keys: #{unsupported_keys.join(", ")}. Allowed keys: #{allowed_keys.join(", ")}"
        expect(missing_keys).to be_empty,
        "#{label} is missing required upcoming_change keys: #{missing_keys.join(", ")}"

        expect(valid_statuses).to include(status),
        "#{label} has invalid upcoming_change status #{status.inspect}. Valid statuses: #{valid_statuses.join(", ")}"

        expect(impact_parts.length).to eq(2),
        "#{label} must set upcoming_change.impact as `type,role`, got #{impact.inspect}"

        if impact_parts.length == 2
          impact_type, impact_role = impact_parts

          expect(valid_upcoming_change_impact_types).to include(impact_type),
          "#{label} has invalid upcoming_change impact type #{impact_type.inspect}. Valid types: #{valid_upcoming_change_impact_types.join(", ")}"
          expect(valid_upcoming_change_impact_roles).to include(impact_role),
          "#{label} has invalid upcoming_change impact role #{impact_role.inspect}. Valid roles: #{valid_upcoming_change_impact_roles.join(", ")}"
        end

        if metadata.key?(:disallow_enabled_for_groups)
          expect(metadata[:disallow_enabled_for_groups]).to eq(true),
          "#{label} should omit `upcoming_change.disallow_enabled_for_groups` unless it is `true`"
        end
      end
    end
  end
end
