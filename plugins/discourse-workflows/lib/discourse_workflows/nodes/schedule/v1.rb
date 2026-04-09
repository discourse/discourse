# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Schedule
      class V1 < NodeType
        HOUR_OPTIONS = (0..23).to_a.freeze
        WEEKDAY_OPTIONS = [1, 2, 3, 4, 5, 6, 0].freeze

        def self.identifier
          "trigger:schedule"
        end

        def self.icon
          "calendar-days"
        end

        def self.color
          "orange"
        end

        def self.manually_triggerable?
          true
        end

        def self.output_schema
          { timestamp: :string }
        end

        def self.configuration_schema
          {
            rules: {
              type: :collection,
              required: true,
              ui: {
                flat: true,
              },
              item_schema: {
                interval: {
                  type: :options,
                  required: true,
                  default: "days",
                  options: %w[seconds minutes hours days weeks months cron],
                  ui: {
                    expression: false,
                  },
                },
                seconds_between_triggers: {
                  type: :integer,
                  default: 30,
                  min: 1,
                  max: 59,
                  visible_if: {
                    interval: %w[seconds],
                  },
                  ui: {
                    expression: false,
                  },
                },
                minutes_between_triggers: {
                  type: :integer,
                  default: 5,
                  min: 1,
                  max: 59,
                  visible_if: {
                    interval: %w[minutes],
                  },
                  ui: {
                    expression: false,
                  },
                },
                hours_between_triggers: {
                  type: :integer,
                  default: 1,
                  min: 1,
                  max: 23,
                  visible_if: {
                    interval: %w[hours],
                  },
                  ui: {
                    expression: false,
                  },
                },
                days_between_triggers: {
                  type: :integer,
                  default: 1,
                  min: 1,
                  max: 31,
                  visible_if: {
                    interval: %w[days],
                  },
                  ui: {
                    expression: false,
                  },
                },
                weeks_between_triggers: {
                  type: :integer,
                  default: 1,
                  min: 1,
                  max: 52,
                  visible_if: {
                    interval: %w[weeks],
                  },
                  ui: {
                    expression: false,
                  },
                },
                months_between_triggers: {
                  type: :integer,
                  default: 1,
                  min: 1,
                  max: 12,
                  visible_if: {
                    interval: %w[months],
                  },
                  ui: {
                    expression: false,
                  },
                },
                trigger_on_weekdays: {
                  type: :options,
                  default: [0],
                  options: WEEKDAY_OPTIONS,
                  visible_if: {
                    interval: %w[weeks],
                  },
                  ui: {
                    control: :multi_combo_box,
                    option_format: :weekday,
                    expression: false,
                  },
                },
                trigger_at_day_of_month: {
                  type: :integer,
                  default: 1,
                  min: 1,
                  max: 31,
                  visible_if: {
                    interval: %w[months],
                  },
                  ui: {
                    expression: false,
                  },
                },
                trigger_at_hour: {
                  type: :options,
                  default: 0,
                  options: HOUR_OPTIONS,
                  visible_if: {
                    interval: %w[days weeks months],
                  },
                  ui: {
                    control: :combo_box,
                    option_format: :hour_of_day,
                    expression: false,
                  },
                },
                trigger_at_minute: {
                  type: :integer,
                  default: 0,
                  min: 0,
                  max: 59,
                  visible_if: {
                    interval: %w[hours days weeks months],
                  },
                  ui: {
                    expression: false,
                  },
                },
                cron: {
                  type: :string,
                  validate: :cron,
                  visible_if: {
                    interval: %w[cron],
                  },
                },
              },
            },
          }
        end

        def initialize(*)
          super(configuration: {})
        end

        def self.validate_configuration(configuration, errors)
          configuration = configuration.is_a?(Hash) ? configuration.with_indifferent_access : {}
          rules = ScheduleRule.rules_from_configuration(configuration)

          if rules.empty?
            errors.add(:base, I18n.t("discourse_workflows.errors.schedule_rules_required"))
            return
          end

          rules.each do |rule|
            next if ScheduleRule.valid_rule?(rule)

            errors.add(:base, I18n.t("discourse_workflows.errors.invalid_schedule_rule"))
            break
          end
        end

        def output
          { timestamp: Time.current.utc.iso8601 }
        end
      end
    end
  end
end
