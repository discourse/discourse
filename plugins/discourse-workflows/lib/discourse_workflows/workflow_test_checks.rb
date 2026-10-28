# frozen_string_literal: true

module DiscourseWorkflows
  module WorkflowTestChecks
    SPECIAL_EFFECTS = %w[nothing finishes].freeze
    MODES = %w[happens not_happens count].freeze
    OPERATORS = %w[equals not_equals contains not_contains].freeze
    MAX_CHECKS = 20
    MAX_CONDITIONS = 10
    MAX_COUNT = 1000
    MAX_VALUE_LENGTH = 1000

    def self.normalize(checks)
      Array
        .wrap(checks)
        .map do |check|
          check = (check.respond_to?(:to_h) ? check.to_h : {}).deep_stringify_keys
          {
            "id" => check["id"].presence || SecureRandom.uuid,
            "effect" => check["effect"].to_s,
            "mode" => check["mode"].presence || "happens",
            "count" => check["count"].nil? ? 1 : check["count"],
            "conditions" => normalize_conditions(check["conditions"]),
          }
        end
    end

    def self.normalize_conditions(conditions)
      Array
        .wrap(conditions)
        .map do |condition|
          condition = (condition.respond_to?(:to_h) ? condition.to_h : {}).deep_stringify_keys
          {
            "id" => condition["id"].presence || SecureRandom.uuid,
            "field" => condition["field"].to_s,
            "operator" => condition["operator"].presence || "equals",
            "value" => condition["value"].nil? ? "" : condition["value"].to_s,
          }
        end
    end

    def self.errors_for(checks)
      errors = []
      if checks.size > MAX_CHECKS
        errors << I18n.t("discourse_workflows.tests.errors.too_many_checks", limit: MAX_CHECKS)
      end

      checks.each do |check|
        effect = check["effect"]
        unless valid_effect?(effect)
          next errors << I18n.t("discourse_workflows.tests.errors.unknown_effect", effect:)
        end
        next if SPECIAL_EFFECTS.include?(effect)

        if MODES.exclude?(check["mode"])
          errors << I18n.t("discourse_workflows.tests.errors.unknown_mode", mode: check["mode"])
        end
        if check["mode"] == "count" && !count_valid?(check["count"])
          errors << I18n.t("discourse_workflows.tests.errors.invalid_count", limit: MAX_COUNT)
        end
        if check["conditions"].size > MAX_CONDITIONS
          errors << I18n.t(
            "discourse_workflows.tests.errors.too_many_conditions",
            limit: MAX_CONDITIONS,
          )
        end
        check["conditions"].each { |condition| errors.concat(condition_errors(effect, condition)) }
      end

      errors.uniq
    end

    def self.valid_effect?(effect)
      SPECIAL_EFFECTS.include?(effect) || Effects.type?(effect.to_s.presence || "-")
    end

    def self.count_valid?(count)
      count.is_a?(Integer) && count.between?(0, MAX_COUNT)
    end

    def self.condition_errors(effect, condition)
      errors = []
      fields = Effects.fields_for(effect).map(&:to_s)
      if fields.exclude?(condition["field"])
        errors << I18n.t(
          "discourse_workflows.tests.errors.unknown_field",
          field: condition["field"],
          effect:,
        )
      end
      if OPERATORS.exclude?(condition["operator"])
        errors << I18n.t(
          "discourse_workflows.tests.errors.unknown_operator",
          operator: condition["operator"],
        )
      end
      if condition["value"].length > MAX_VALUE_LENGTH
        errors << I18n.t("discourse_workflows.tests.errors.value_too_long", limit: MAX_VALUE_LENGTH)
      end
      errors
    end

    def self.finishes
      {
        "id" => SecureRandom.uuid,
        "effect" => "finishes",
        "mode" => "happens",
        "count" => 1,
        "conditions" => [],
      }
    end

    def self.from_effect(effect)
      type = effect["type"].to_s
      field = Effects.fields_for(type).first.to_s
      value = effect.dig("fields", field)
      conditions =
        if value.nil? || value.to_s.empty?
          []
        else
          [
            {
              "id" => SecureRandom.uuid,
              "field" => field,
              "operator" => "equals",
              "value" => value.to_s,
            },
          ]
        end
      {
        "id" => SecureRandom.uuid,
        "effect" => type,
        "mode" => "happens",
        "count" => 1,
        "conditions" => conditions,
      }
    end

    def self.from_effects(effects)
      effects
        .map { |effect| effect["type"].to_s }
        .uniq
        .filter_map do |type|
          next unless Effects.type?(type)
          from_effect(effects.find { |effect| effect["type"].to_s == type })
        end
    end
  end
end
