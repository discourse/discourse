# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserSeen
      class V1 < NodeType
        TRIGGER_ON_OPTIONS = %w[first_seen every_time_seen not_seen_for_more_than].freeze
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
          properties: {
            trigger_on: {
              type: :options,
              required: true,
              default: "first_seen",
              options: TRIGGER_ON_OPTIONS,
            },
            not_seen_for_amount: {
              type: :integer,
              required: true,
              default: 30,
              min: 1,
              display_options: {
                show: {
                  trigger_on: %w[not_seen_for_more_than],
                },
              },
            },
            not_seen_for_unit: {
              type: :options,
              required: true,
              default: "days",
              options: NOT_SEEN_UNITS,
              display_options: {
                show: {
                  trigger_on: %w[not_seen_for_more_than],
                },
              },
            },
          },
          capabilities: {
            provides_current_user: true,
          },
        )

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
          case trigger_ctx.get_node_parameter("trigger_on", "first_seen").presence || "first_seen"
          when "every_time_seen"
            true
          when "first_seen"
            first_seen?
          when "not_seen_for_more_than"
            not_seen_for_more_than?(trigger_ctx)
          else
            false
          end
        end

        private

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
          return true if previous_seen_at.blank?

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
