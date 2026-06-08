# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserLoggedIn
      class V1 < NodeType
        TRIGGER_ON_OPTIONS = %w[first_login every_login previous_visit_more_than].freeze
        PREVIOUS_VISIT_UNITS = %w[hours days weeks months].freeze

        description(
          name: "trigger:user_logged_in",
          version: "1.0",
          defaults: {
            icon: "user-check",
            color: "green",
          },
          group: "discourse_triggers",
          events: [:user_logged_in],
          properties: {
            trigger_on: {
              type: :options,
              required: true,
              default: "first_login",
              options: TRIGGER_ON_OPTIONS,
            },
            previous_visit_amount: {
              type: :integer,
              required: true,
              default: 30,
              min: 1,
              display_options: {
                show: {
                  trigger_on: %w[previous_visit_more_than],
                },
              },
            },
            previous_visit_unit: {
              type: :options,
              required: true,
              default: "days",
              options: PREVIOUS_VISIT_UNITS,
              display_options: {
                show: {
                  trigger_on: %w[previous_visit_more_than],
                },
              },
            },
          },
          capabilities: {
            provides_current_user: true,
          },
        )

        def initialize(user)
          super(parameters: {})
          @user = user
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
            login: {
              first_login: first_login?,
              previous_seen_at: previous_seen_at&.iso8601,
              seconds_since_previous_seen: seconds_since_previous_seen,
            },
          }
        end

        def matches?(trigger_ctx)
          case trigger_ctx.get_node_parameter("trigger_on", "first_login").presence || "first_login"
          when "every_login"
            true
          when "first_login"
            first_login?
          when "previous_visit_more_than"
            previous_seen_more_than?(trigger_ctx)
          else
            false
          end
        end

        private

        def first_login?
          !@user.seen_before?
        end

        def previous_seen_at
          @user.last_seen_at
        end

        def seconds_since_previous_seen
          return nil if previous_seen_at.blank?

          (Time.current - previous_seen_at).to_i
        end

        def previous_seen_more_than?(trigger_ctx)
          return false if previous_seen_at.blank?

          amount = trigger_ctx.get_node_parameter("previous_visit_amount", 30).to_i
          unit = trigger_ctx.get_node_parameter("previous_visit_unit", "days").presence || "days"

          amount.positive? && PREVIOUS_VISIT_UNITS.include?(unit) &&
            previous_seen_at <= amount.public_send(unit).ago
        end

        def user_data(user)
          serialize_record(user, BasicUserSerializer)
        end
      end
    end
  end
end
