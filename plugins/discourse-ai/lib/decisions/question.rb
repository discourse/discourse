# frozen_string_literal: true

module DiscourseAi
  module Decisions
    # Provider-neutral question asked of a decision model. Endpoints translate it
    # into their own wire format.
    #
    # Usually built from a hash, which round-trips through #to_h:
    #
    #   { type: "yes_no", name: "spam", instructions: "Is this spam?" }
    #   { type: "choice", name: "team", instructions: "Who handles it?",
    #     choices: [{ value: "billing", description: "Payments" }, { value: "returns" }] }
    #   { type: "score", name: "severity", instructions: "How bad is it?",
    #     levels: [{ label: "low", description: "Minor annoyance" }, { label: "high" }] }
    class Question
      TYPES = %i[yes_no choice score].freeze
      # Names must work as identifiers in workflow expressions, e.g. `answers.is_spam`.
      NAME_FORMAT = /\A[A-Za-z_][A-Za-z0-9_]{0,63}\z/
      CHOICES_RANGE = (2..255)
      LEVELS_RANGE = (2..10)

      attr_reader :name, :type, :instructions, :choices, :levels

      def self.wrap(question)
        question.is_a?(Question) ? question : from_h(question)
      end

      def self.from_h(hash)
        if !hash.respond_to?(:to_h) || hash.is_a?(Array)
          raise InvalidQuestion.new("Questions must be hashes", name: nil)
        end

        hash = hash.to_h.deep_symbolize_keys
        new(**hash.slice(:name, :type, :instructions, :choices, :levels))
      end

      def self.yes_no(name, instructions)
        new(name:, type: :yes_no, instructions:)
      end

      # @param choices [Array<Hash>, Hash{String => String, nil}] `[{ value:, description: }]`,
      #   or the `{ value => description }` shorthand
      def self.choice(name, instructions, choices)
        new(name:, type: :choice, instructions:, choices:)
      end

      # @param levels [Array<Hash, String>] ordered lowest to highest, each `{ label:, description: }`
      #   or a plain label
      def self.score(name, instructions, levels)
        new(name:, type: :score, instructions:, levels:)
      end

      def initialize(name:, type:, instructions:, choices: nil, levels: nil)
        @name = name.to_s
        validate_name!
        @type = type.to_s.to_sym
        @instructions = instructions.to_s
        @choices = normalize_choices(choices) if @type == :choice
        @levels = normalize_levels(levels) if @type == :score

        validate!
      end

      def to_h
        { type: type.to_s, name:, instructions:, choices:, levels: }.compact
      end

      def as_json(*) = to_h.as_json

      private

      def normalize_choices(choices)
        case choices
        when Hash
          choices.map { |value, description| { value: value.to_s, description: }.compact }
        when Array
          choices.map do |choice|
            if !choice.is_a?(Hash)
              invalid!("Each choice must be a hash with a value", field: :choices)
            end
            choice = choice.symbolize_keys
            { value: choice[:value].to_s, description: choice[:description].presence }.compact
          end
        else
          invalid!("Choices are required", field: :choices)
        end
      end

      def normalize_levels(levels)
        invalid!("Levels are required", field: :levels) if !levels.is_a?(Array)

        levels.map do |level|
          if level.is_a?(Hash)
            level = level.symbolize_keys
            label = (level[:label].presence || level[:description]).to_s
            { label:, description: level[:description].presence }.compact
          else
            { label: level.to_s }
          end
        end
      end

      def validate_name!
        if !name.match?(NAME_FORMAT)
          invalid!(
            "Question names must start with a letter or underscore and contain only letters, digits and underscores",
            field: :name,
          )
        end
      end

      def validate!
        invalid!("Unknown question type: #{type}", field: :type) if TYPES.exclude?(type)
        invalid!("Instructions are required", field: :instructions) if instructions.blank?

        case type
        when :choice
          validate_options!(choices.map { |choice| choice[:value] }, CHOICES_RANGE, :choices)
        when :score
          validate_options!(levels.map { |level| level[:label] }, LEVELS_RANGE, :levels)
        end
      end

      def validate_options!(keys, range, field)
        if !range.cover?(keys.size)
          invalid!("Needs between #{range.min} and #{range.max} #{field}", field:)
        end
        invalid!("#{field.to_s.capitalize} can't be blank", field:) if keys.any?(&:blank?)
        invalid!("#{field.to_s.capitalize} must be unique", field:) if keys.uniq.size != keys.size
      end

      def invalid!(message, field:)
        raise InvalidQuestion.new("#{name.presence || "Question"}: #{message}", name:, field:)
      end
    end
  end
end
