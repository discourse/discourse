# frozen_string_literal: true

# = Service::StepsInspector
#
# This class takes a {Service::Base::Context} object and inspects it.
# It will output a list of steps and what is their known state.
class Service::StepsInspector
  # @!visibility private
  class Step
    COLORS = { red: 31, green: 32, white: 37, gray: 90 }

    attr_reader :step, :result, :nesting_level, :color

    delegate :name, :result_key, to: :step
    delegate :failure?,
             :success?,
             :error,
             :raised_exception?,
             :skipped?,
             to: :step_result,
             allow_nil: true

    alias error? failure?

    def self.for(step, result, nesting_level: 0, color: nil)
      class_name =
        "#{module_parent_name}::#{step.class.name.split("::").last.sub(/^(\w+)Step$/, "\\1")}"
      class_name.constantize.new(step, result, nesting_level:, color:)
    end

    def initialize(step, result, nesting_level: 0, color: nil)
      @step = step
      @result = result
      @nesting_level = nesting_level
      @color = color
    end

    def type
      self.class.name.split("::").last.underscore
    end
    alias inspect_type type

    def emoji
      "#{result_emoji}#{unexpected_result_emoji}"
    end

    def steps
      [self]
    end

    def inspect
      "#{"  " * nesting_level}\e[#{ansi_color}m[#{inspect_type}] #{name}#{runtime}\e[0m #{emoji}".rstrip
    end

    private

    def runtime
      return unless step_result&.__runtime__
      " (#{(step_result.__runtime__ * 1000).round(4)} ms)"
    end

    def step_result
      result[result_key]
    end

    def result_emoji
      return "💥" if raised_exception?
      return "⏭️" if skipped?
      return "❌" if failure?
      return "✅" if success?
      ""
    end

    def unexpected_result_emoji
      " ⚠️#{unexpected_result_text}" if step_result.try(:[], "spec.unexpected_result")
    end

    def unexpected_result_text
      return "  <= expected to return true but got false instead" if error?
      "  <= expected to return false but got true instead"
    end

    def ansi_color
      return color if color
      return COLORS[:red] if failure?
      return COLORS[:green] if success?
      COLORS[:white]
    end
  end

  # @!visibility private
  class Model < Step
    def error
      return result[name].errors.inspect if step_result.invalid
      step_result.exception&.full_message || "Model not found"
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
      [
        self,
        *step.steps.map { Step.for(_1, result, nesting_level: nesting_level + 1, color:).steps },
      ]
    end

    def inspect
      "#{"  " * nesting_level}\e[#{ansi_color}m[#{inspect_type}]#{runtime}\e[0m#{unexpected_result_emoji}"
    end
  end

  # @!visibility private
  class Options < Step
  end

  # @!visibility private
  class Try < Transaction
    def error?
      step_result.exception
    end

    def error
      step_result.exception.full_message
    end
  end

  # @!visibility private
  class Lock < Transaction
    def inspect
      "#{"  " * nesting_level}\e[#{ansi_color}m[#{inspect_type}] #{name}#{runtime}\e[0m #{emoji}".rstrip
    end

    def error
      "Lock '#{name}' was not acquired."
    end
  end

  # @!visibility private
  class OnlyIf < Step
    def steps
      [
        self,
        *step.steps.map do
          Step.for(_1, result, nesting_level: nesting_level + 1, color: skipped_color).steps
        end,
      ]
    end

    def inspect
      "#{"  " * nesting_level}\e[#{ansi_color}m[#{inspect_type}] #{name}#{runtime}\e[0m #{emoji}#{explanation}".rstrip
    end

    private

    def explanation
      return unless skipped?
      " (condition was not met)"
    end

    def ansi_color
      return super unless skipped?
      COLORS[:white]
    end

    def skipped_color
      return unless skipped?
      COLORS[:gray]
    end
  end

  attr_reader :steps, :result

  def initialize(result)
    @steps = result.__steps__.map { Step.for(_1, result).steps }.flatten
    @result = result
  end

  def inspect
    output = <<~OUTPUT
    Inspecting #{result.__service_class__} result object:

    #{execution_flow}
    OUTPUT
    output += "\nWhy it failed:\n\n#{error}" if error.present?
    output
  end

  # Example output:
  #   [1/4] [model] channel (0.02 ms) ✅
  #   [2/4] [params] default (0.1 ms) ✅
  #   [3/4] [policy] check_channel_permission ❌
  #   [4/4] [step] change_status
  # @return [String] the steps of the result object with their state
  def execution_flow
    steps
      .filter_map
      .with_index do |step, index|
        next if @encountered_error
        @encountered_error = index + 1 if step.failure?
        "[#{format("%#{steps.size.to_s.size}s", index + 1)}/#{steps.size}] #{step.inspect}"
      end
      .join("\n")
      .then do |output|
        skipped_steps = steps.size - @encountered_error.to_i
        next output unless @encountered_error && skipped_steps.positive?
        "#{output}\n\n(#{skipped_steps} more steps not shown as the execution flow was stopped before reaching them)"
      end
  end

  # @return [String, nil] the first available error, if any.
  def error
    steps.detect(&:error?)&.error
  end
end
