# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    module Schedule
      class V1 < Triggers::Base
        def self.identifier
          "trigger:schedule"
        end

        def self.icon
          "calendar-days"
        end

        def self.color_key
          "orange"
        end

        def self.manually_triggerable?
          true
        end

        def self.output_schema
          { timestamp: :string }
        end

        def self.configuration_schema
          { cron: { type: :string, required: true, validate: :cron } }
        end

        def self.validate_configuration(configuration, errors)
          configuration = configuration.is_a?(Hash) ? configuration.with_indifferent_access : {}
          cron = configuration[:cron]
          return if DiscourseWorkflows::CronParser.valid?(cron)

          errors.add(:base, I18n.t("discourse_workflows.errors.invalid_cron_expression"))
        end

        def output
          { timestamp: Time.current.utc.iso8601 }
        end
      end
    end
  end
end
