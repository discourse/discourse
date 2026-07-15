# frozen_string_literal: true

def upcoming_change_setting_files
  [
    Rails.root.join("config/site_settings.yml").to_s,
    *Dir["#{Rails.root.join("plugins/*/config/settings.yml")}"].sort,
  ]
end

def each_upcoming_change_setting
  upcoming_change_setting_files.each do |file|
    SiteSettings::YamlLoader
      .new(file)
      .load do |category, setting_name, default, opts|
        next if opts[:upcoming_change].blank?

        setting = {
          file: file.delete_prefix("#{Rails.root.join("")}"),
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
      allowed_keys = %i[
        status
        impact
        learn_more_url
        allow_enabled_for
        body_class
        permanent_warning
        hide_settings
        requires_plugin_enabled
      ]
      required_keys = %i[status impact]
      unsupported_keys = metadata.keys - allowed_keys
      missing_keys = required_keys - metadata.keys
      valid_statuses = UpcomingChanges.statuses.keys
      status = metadata[:status].to_sym
      impact = metadata[:impact]
      impact_parts = impact.is_a?(String) ? impact.split(",") : []
      learn_more_url = metadata[:learn_more_url]
      allow_enabled_for = metadata[:allow_enabled_for]
      body_class = metadata[:body_class]
      permanent_warning = metadata[:permanent_warning]
      hide_settings = metadata[:hide_settings]
      requires_plugin_enabled = metadata[:requires_plugin_enabled]
      owning_plugin = Discourse.plugins_by_name[SiteSetting.plugins[setting[:setting]]]

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

        if status != :conceptual
          aggregate_failures do
            expect(learn_more_url).to be_present,
            "#{label} must set `upcoming_change.learn_more_url` when status is not `conceptual`"

            if learn_more_url.present?
              expect(learn_more_url).to match(%r{\Ahttps://meta\.discourse\.org/t/-/\d+\z}),
              "#{label} upcoming_change.learn_more_url must match https://meta.discourse.org/t/-/NNNN, do not include the topic slug"
            end
          end
        end

        if allow_enabled_for.present?
          valid_values = %w[everyone staff specific_groups]
          allow_strings = Array(allow_enabled_for).map(&:to_s)

          expect(allow_enabled_for).to be_an(Array),
          "#{label} `upcoming_change.allow_enabled_for` must be an array"
          expect(allow_strings).not_to be_empty,
          "#{label} `upcoming_change.allow_enabled_for` must not be empty"
          expect(allow_strings - valid_values).to be_empty,
          "#{label} `upcoming_change.allow_enabled_for` contains invalid values: #{(allow_strings - valid_values).join(", ")}. Valid values: #{valid_values.join(", ")}"

          if allow_strings.include?("everyone")
            expect(allow_strings).to eq(["everyone"]),
            "#{label} `upcoming_change.allow_enabled_for` may not combine `everyone` with other values"
          end
        end

        unless body_class.nil?
          expect([true, false]).to include(body_class),
          "#{label} `upcoming_change.body_class` must be a boolean"
        end

        unless permanent_warning.nil?
          expect([true, false]).to include(permanent_warning),
          "#{label} `upcoming_change.permanent_warning` must be a boolean"
        end

        unless requires_plugin_enabled.nil?
          expect([true, false]).to include(requires_plugin_enabled),
          "#{label} `upcoming_change.requires_plugin_enabled` must be a boolean"

          expect(owning_plugin).to be_present,
          "#{label} sets `upcoming_change.requires_plugin_enabled` but is not owned by a plugin"

          if owning_plugin.present?
            expect(owning_plugin.enabled_site_setting&.to_sym).not_to eq(setting[:setting]),
            "#{label} may not set `upcoming_change.requires_plugin_enabled` on its own plugin's `enabled_site_setting` -- the change would gate itself"
          end
        end

        if hide_settings.present?
          expect(hide_settings).to be_an(Array),
          "#{label} `upcoming_change.hide_settings` must be an array"

          unknown_settings =
            Array(hide_settings).map(&:to_s).reject { |s| SiteSetting.respond_to?(s) }
          expect(unknown_settings).to be_empty,
          "#{label} `upcoming_change.hide_settings` references unknown site settings: #{unknown_settings.join(", ")}"
        end
      end
    end
  end
end
