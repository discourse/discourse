# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module SiteSettingUpdate
      class V1 < NodeType
        description(
          name: "action:site_setting",
          version: "1.0",
          defaults: {
            icon: "sliders",
            color: "orange",
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          output_contracts: [
            {
              schema: {
                "$schema" => Schema::DRAFT_URI,
                "type" => "object",
                "properties" => {
                  "name" => {
                    "type" => "string",
                  },
                  "value" => {
                    "type" => "string",
                  },
                  "previous_value" => {
                    "type" => "string",
                  },
                  "changed" => {
                    "type" => "boolean",
                  },
                },
              },
            },
          ],
          properties: {
            name: {
              type: :string,
              required: true,
              type_options: {
                load_options_method: "site_settings",
              },
              ui: {
                control: :combo_box,
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
                none: "discourse_workflows.site_setting.name_placeholder",
              },
            },
            value: {
              type: :string,
              required: false,
              default: "",
            },
            actor_username: {
              type: :string,
              required: false,
              default: "system",
              ui: {
                control: :actor,
              },
            },
          },
        )

        def self.load_options_context(context)
          case context.method_name
          when "site_settings"
            settable_setting_names
              .select { |name| context.matches_filter?(name) }
              .map { |name| { id: name, name: name } }
          end
        end

        # Mirrors what the admin settings UI lets an admin change, minus secrets:
        # a workflow stores its parameters in plain text, so secret values must
        # never flow through one.
        def self.settable_setting_names
          hidden = ::SiteSetting.hidden_settings
          deprecated =
            SiteSettings::DeprecatedSettings::SETTINGS.map { |old_name, *| old_name.to_sym }

          ::SiteSetting
            .defaults
            .all
            .keys
            .reject do |name|
              hidden.include?(name) || ::SiteSetting.secret_settings.include?(name) ||
                ::SiteSetting.shadowed_settings.include?(name) || ::SiteSetting.themeable[name] ||
                deprecated.include?(name) || unconfigurable_plugin_setting?(name)
            end
            .map(&:to_s)
            .sort
        end

        def self.unconfigurable_plugin_setting?(name)
          plugin_name = ::SiteSetting.plugins[name]
          plugin_name.present? && !Discourse.plugins_by_name[plugin_name].configurable?
        end

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              config = {
                "name" => exec_ctx.get_node_parameter("name", item_index),
                "value" => exec_ctx.get_node_parameter("value", item_index, default: ""),
              }

              wrap(process(exec_ctx, config, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, config, item_index)
          name = config["name"].to_s.strip
          if name.blank?
            raise_node_error!(I18n.t("discourse_workflows.errors.site_setting.name_required"))
          end
          ensure_settable!(name)

          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          previous_value = ::SiteSetting.public_send(name)
          output = nil

          ::SiteSetting::Update.call(
            guardian: actor.guardian,
            params: {
              settings: [{ setting_name: name, value: config["value"].to_s }],
            },
          ) do
            on_success { output = output_for(name, previous_value) }
            on_failed_policy(:current_user_is_admin) do
              raise_node_error!(
                I18n.t(
                  "discourse_workflows.errors.site_setting.actor_not_admin",
                  username: actor.username,
                ),
              )
            end
            on_failed_policy(:settings_are_not_deprecated) do |policy|
              raise_node_error!(policy.reason)
            end
            on_failed_policy(:settings_are_unshadowed_globally) do |policy|
              raise_node_error!(policy.reason)
            end
            on_failed_policy(:settings_are_visible) { |policy| raise_node_error!(policy.reason) }
            on_failed_policy(:settings_are_configurable) do |policy|
              raise_node_error!(policy.reason)
            end
            on_failed_contract do |contract|
              raise_update_failed!(name, contract.errors.full_messages.join(", "))
            end
            on_exceptions { |error| raise_update_failed!(name, error.message) }
            on_failure { raise_update_failed!(name, nil) }
          end

          output
        end

        def ensure_settable!(name)
          unless ::SiteSetting.has_setting?(name)
            raise_node_error!(
              I18n.t("discourse_workflows.errors.site_setting.unknown_setting", name: name),
            )
          end

          if ::SiteSetting.secret_settings.include?(name.to_sym)
            raise_node_error!(
              I18n.t("discourse_workflows.errors.site_setting.secret_setting", name: name),
            )
          end
        end

        def raise_update_failed!(name, errors)
          raise_node_error!(
            I18n.t(
              "discourse_workflows.errors.site_setting.update_failed",
              name: name,
              errors:
                errors.presence || I18n.t("discourse_workflows.errors.site_setting.unknown_error"),
            ),
          )
        end

        def output_for(name, previous_value)
          current_value = ::SiteSetting.public_send(name)

          {
            name: name,
            value: display_value(current_value),
            previous_value: display_value(previous_value),
            changed: current_value != previous_value,
          }
        end

        def display_value(value)
          Array.wrap(value).map { |entry| entry.is_a?(::Upload) ? entry.url : entry.to_s }.join("|")
        end
      end
    end
  end
end
