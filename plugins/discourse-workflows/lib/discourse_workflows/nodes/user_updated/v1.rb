# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserUpdated
      class V1 < NodeType
        CHANGED_FIELDS = {
          "avatar" => %w[uploaded_avatar_id],
          "bio" => %w[bio_raw bio_cooked],
          "name" => %w[name],
          "username" => %w[username],
          "email" => %w[email],
          "website" => %w[website],
          "location" => %w[location],
          "title" => %w[title],
          "profile_images" => %w[profile_background_upload_id card_background_upload_id],
        }.freeze

        description(
          name: "trigger:user_updated",
          version: "1.0",
          defaults: {
            icon: "user-pen",
            color: "teal",
          },
          group: "discourse_triggers",
          events: [:user_updated],
          output_contracts: [{ schema: Schema::USER_UPDATED_EVENT_SCHEMA }],
          properties: {
            changed_fields: {
              type: :multi_options,
              required: false,
              default: [],
              options: CHANGED_FIELDS.keys,
            },
            group_ids: {
              type: :multi_options,
              required: false,
              default: [],
              type_options: {
                load_options_method: "groups",
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
              },
            },
          },
          capabilities: {
            provides_current_user: true,
          },
        )

        def self.load_options_context(context)
          case context.method_name
          when "groups"
            ::Group
              .order(:name)
              .pluck(:id, :name)
              .select { |_, name| context.matches_filter?(name) }
              .map { |id, name| { id:, name: } }
          end
        end

        def self.changed_names_for(columns)
          return nil if columns.nil?

          columns = Array.wrap(columns).map(&:to_s)
          CHANGED_FIELDS.filter_map { |name, mapped| name if mapped.intersect?(columns) }
        end

        def initialize(user, changed_columns = nil, *)
          super(parameters: {})
          @user = user
          @changed = self.class.changed_names_for(changed_columns)
        end

        def valid?
          @user.present? && @user.human?
        end

        def user_id
          @user.id
        end

        def output
          {
            user:
              serialize_user(@user).merge(
                staged: @user.staged?,
                created_at: @user.created_at&.iso8601,
              ),
            changed: @changed,
          }
        end

        def matches?(trigger_ctx)
          matches_changed_fields?(trigger_ctx.get_node_parameter("changed_fields", [])) &&
            matches_user_groups?(@user, trigger_ctx.get_node_parameter("group_ids", []))
        end

        private

        def matches_changed_fields?(selected)
          selected = Array.wrap(selected).compact_blank.map(&:to_s)
          return true if selected.empty? || @changed.nil?

          selected.intersect?(@changed)
        end
      end
    end
  end
end
