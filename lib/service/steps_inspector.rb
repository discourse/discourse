# frozen_string_literal: true

# = Service::StepsInspector
#
# This class takes a {Service::Base::Context} object and inspects it.
# It will output a list of steps and what is their known state.
class Service::StepsInspector
  # @!visibility private
  class Step
    attr_reader :step, :result, :nesting_level

    delegate :name, to: :step
    delegate :failure?, :success?, :error, to: :step_result, allow_nil: true

    def self.for(step, result, nesting_level: 0)
      class_name =
        "#{module_parent_name}::#{step.class.name.split("::").last.sub(/^(\w+)Step$/, "\\1")}"
      class_name.constantize.new(step, result, nesting_level: nesting_level)
    end

    def initialize(step, result, nesting_level: 0)
      @step = step
      @result = result
      @nesting_level = nesting_level
    end

    def type
      self.class.name.split("::").last.downcase
    end
    alias inspect_type type

    def emoji
      "#{result_emoji}#{unexpected_result_emoji}"
    end

    def steps
      [self]
    end

    def inspect
      "#{"  " * nesting_level}[#{inspect_type}] '#{name}' #{emoji}".rstrip
    end

    private

    def step_result
      result["result.#{type}.#{name}"]
    end

    def result_emoji
      return "❌" if failure?
      return "✅" if success?
      ""
    end

    def unexpected_result_emoji
      " ⚠️#{unexpected_result_text}" if step_result.try(:[], "spec.unexpected_result")
    end

    def unexpected_result_text
      return "  <= expected to return true but got false instead" if failure?
      "  <= expected to return false but got true instead"
    end
  end

  # @!visibility private
  class Model < Step
    def error
      return result[name].errors.inspect if step_result.invalid
      step_result.exception.full_message
    end
  end

  # @!visibility private
  class Contract < Step
    def error
      "#{step_result.errors.inspect}\n\nProvided parameters: #{step_result.parameters.pretty_inspect}"
    end

    def inspect_type
      "params"
    end
  end

  # @!visibility private
  class Policy < Step
    def error
      step_result.reason
    end
  end

  # @!visibility private
  class Transaction < Step
    def steps
      [self, *step.steps.map { Step.for(_1, result, nesting_level: nesting_level + 1).steps }]
    end

    def inspect
      "#{"  " * nesting_level}[#{type}]"
    end

    def step_result
      nil
    end
  end
  #
  # @!visibility private
  class Options < Step
  end

  attr_reader :steps, :result

  def initialize(result)
    @steps = result.__steps__.map { Step.for(_1, result).steps }.flatten
    @result = result
  end

  # Inspect the provided result object.
  # Example output:
  #   [1/4] [model] 'channel' ✅
  #   [2/4] [params] 'default' ✅
  #   [3/4] [policy] 'check_channel_permission' ❌
  #   [4/4] [step] 'change_status'
  # @return [String] the steps of the result object with their state
  def inspect
    steps.map.with_index { |step, index| "[#{index + 1}/#{steps.size}] #{step.inspect}" }.join("\n")
  end

  # @return [String, nil] the first available error, if any.
  def error
    steps.detect(&:failure?)&.error
  end
end
