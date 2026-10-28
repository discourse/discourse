# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTestEvaluator
    COULD_NOT_RUN_KINDS = %w[safety timeout engine].freeze

    def self.call(checks:, effects:, error_kind: nil, failed_step: nil, error_message: nil)
      new(checks:, effects:, error_kind:, failed_step:, error_message:).call
    end

    def initialize(checks:, effects:, error_kind:, failed_step:, error_message:)
      @checks = checks
      @effects = effects
      @error_kind = error_kind
      @failed_step = failed_step
      @error_message = error_message
    end

    def call
      if COULD_NOT_RUN_KINDS.include?(@error_kind)
        return result("could_not_run", reason: could_not_run_reason, checks: [])
      end

      evaluated = @checks.map { |check| check.merge(evaluate(check)) }
      failed = evaluated.find { |check| check["status"] == "failed" }
      result(failed ? "failed" : "passed", reason: failed&.fetch("reason"), checks: evaluated)
    end

    private

    def result(status, reason:, checks:)
      {
        "status" => status,
        "reason" => reason,
        "checks" => checks,
        "error_kind" => @error_kind,
        "failed_step" => @failed_step,
      }
    end

    def could_not_run_reason
      @error_message.presence || I18n.t("discourse_workflows.tests.reasons.could_not_run")
    end

    def stopped?
      @error_kind == "node"
    end

    def evaluate(check)
      case check["effect"]
      when "finishes"
        stopped? ? failed(:stopped_with_error, step: @failed_step, message: @error_message) : passed
      when "nothing"
        if @effects.empty?
          passed
        else
          failed(:something_happened, count: @effects.size, first: sentence(@effects.first))
        end
      else
        evaluate_effect_check(check)
      end
    end

    def evaluate_effect_check(check)
      matches = matching_effects(check)
      same_type = @effects.select { |effect| effect["type"] == check["effect"] }
      expected = effect_label(check["effect"], 1)

      case check["mode"]
      when "not_happens"
        matches.empty? ? passed : failed(:unexpected_effect, first: sentence(matches.first))
      when "count"
        count = check["count"].to_i
        if matches.size == count
          passed
        else
          failed(
            :wrong_count,
            expected: effect_label(check["effect"], count),
            count:,
            actual: matches.size,
          )
        end
      else
        return passed if matches.any?
        return failed(:stopped_before, expected:, step: @failed_step) if stopped?
        if same_type.any?
          failed(:no_match, expected:, first: sentence(same_type.first))
        else
          failed(:missing_effect, expected:)
        end
      end
    end

    def matching_effects(check)
      @effects.select do |effect|
        effect["type"] == check["effect"] &&
          check["conditions"].all? do |condition|
            condition_matches?(condition, effect["fields"] || {})
          end
      end
    end

    def condition_matches?(condition, fields)
      actual = fields[condition["field"]]
      expected = condition["value"].to_s.strip
      if synthetic_id?(condition["field"], actual) &&
           %w[equals contains].include?(condition["operator"])
        return false
      end

      actual_text = actual.to_s.strip
      case condition["operator"]
      when "not_equals"
        actual_text != expected
      when "contains"
        actual_text.downcase.include?(expected.downcase)
      when "not_contains"
        !actual_text.downcase.include?(expected.downcase)
      else
        actual_text == expected
      end
    end

    def synthetic_id?(field, value)
      field.to_s.end_with?("_id") && value.is_a?(Integer) && value.negative?
    end

    def passed
      { "status" => "passed", "reason" => nil }
    end

    def failed(key, **params)
      {
        "status" => "failed",
        "reason" => I18n.t("discourse_workflows.tests.reasons.#{key}", **params),
      }
    end

    def effect_label(type, count)
      I18n.t("discourse_workflows.tests.effects.#{type}", count:, default: type.to_s.humanize)
    end

    def sentence(effect)
      details =
        (effect["fields"] || {})
          .reject { |_field, value| value.nil? || value.to_s.empty? }
          .map { |field, value| "#{field.to_s.humanize(capitalize: false)} #{format_value(value)}" }
      I18n.t(
        "discourse_workflows.tests.sentences.effect",
        effect: effect_label(effect["type"], 1),
        details: details.join(", "),
      )
    end

    def format_value(value)
      value.is_a?(String) ? "\"#{value.truncate(40)}\"" : value.to_s
    end
  end
end
