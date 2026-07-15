# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserSeen
      class V1 < NodeType
        NOT_SEEN_UNITS = %w[hours days weeks months].freeze

        description(
          name: "trigger:user_seen",
          version: "1.0",
          defaults: {
            icon: "user-check",
            color: "green",
          },
          group: "discourse_triggers",
          events: [:user_seen],
          output_contracts: [{ schema: Schema::USER_SEEN_SCHEMA }],
          properties: {
            trigger_conditions: {
              type: :custom,
              ui: {
                control: :user_seen_trigger_options,
              },
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
            trigger_on_first_seen: {
              type: :boolean,
              required: false,
              default: true,
              ui: {
                hidden: true,
              },
            },
            trigger_on_not_seen_for_more_than: {
              type: :boolean,
              required: false,
              default: false,
              ui: {
                hidden: true,
              },
            },
            not_seen_for_amount: {
              type: :integer,
              required: true,
              default: 30,
              min: 1,
              ui: {
                hidden: true,
              },
            },
            not_seen_for_unit: {
              type: :options,
              required: true,
              default: "days",
              options: NOT_SEEN_UNITS,
              ui: {
                hidden: true,
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

        def initialize(user, previous_seen_at = nil)
          super(parameters: {})
          @user = user
          @previous_seen_at = previous_seen_at
        end

        def valid?
          @user.present?
        end

        def user_id
          @user.id
        end

        def output
          {
            user: user_data(@user),
            seen: {
              first_seen: first_seen?,
              current_seen_at: current_seen_at&.iso8601,
              previous_seen_at: previous_seen_at&.iso8601,
              seconds_since_previous_seen: seconds_since_previous_seen,
            },
          }
        end

        def matches?(trigger_ctx)
          matches_groups?(trigger_ctx.get_node_parameter("group_ids", [])) &&
            (matches_first_seen?(trigger_ctx) || matches_not_seen_for_more_than?(trigger_ctx))
        end

        private

        def matches_first_seen?(trigger_ctx)
          trigger_ctx.get_node_parameter("trigger_on_first_seen", true) && first_seen?
        end

        def matches_not_seen_for_more_than?(trigger_ctx)
          trigger_ctx.get_node_parameter("trigger_on_not_seen_for_more_than", false) &&
            not_seen_for_more_than?(trigger_ctx)
        end

        def matches_groups?(group_ids)
          raw_group_ids = Array.wrap(group_ids).reject(&:blank?)
          return true if raw_group_ids.empty?

          group_ids = normalize_group_ids(raw_group_ids)
          group_ids.present? && !!@user&.in_any_groups?(group_ids)
        end

        def normalize_group_ids(group_ids)
          group_ids.filter_map do |group_id|
            value = group_id.to_s
            value.to_i if value.match?(/\A\d+\z/)
          end
        end

        def first_seen?
          previous_seen_at.blank?
        end

        def current_seen_at
          @user.last_seen_at
        end

        def previous_seen_at
          @previous_seen_at
        end

        def seconds_since_previous_seen
          return nil if previous_seen_at.blank? || current_seen_at.blank?

          (current_seen_at - previous_seen_at).to_i
        end

        def not_seen_for_more_than?(trigger_ctx)
          return false if previous_seen_at.blank?

          amount = trigger_ctx.get_node_parameter("not_seen_for_amount", 30).to_i
          unit = trigger_ctx.get_node_parameter("not_seen_for_unit", "days").presence || "days"

          amount.positive? && NOT_SEEN_UNITS.include?(unit) &&
            previous_seen_at <= amount.public_send(unit).ago
        end

        def user_data(user)
          serialize_record(user, BasicUserSerializer)
        end
      end
    end
  end
end
