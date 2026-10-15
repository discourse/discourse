# frozen_string_literal: true

module DiscourseAi
  module Decisions
    class Question
      TYPES = %i[yes_no choice score].freeze
      NAME_FORMAT = /\A[A-Za-z_][A-Za-z0-9_]{0,63}\z/

      attr_reader :name, :type, :instructions, :choices, :levels

      def self.wrap(question)
        return question if question.is_a?(self)
        raise InvalidRequest, "Questions must be hashes" if !question.is_a?(Hash)

        new(**question.symbolize_keys.slice(:name, :type, :instructions, :choices, :levels))
      end

      def initialize(name: nil, type: nil, instructions: nil, choices: nil, levels: nil)
        @name = name.to_s.strip
        if !@name.match?(NAME_FORMAT)
          invalid!(:name, "must be an identifier of at most 64 characters")
        end
        @type = type.to_s.to_sym
        invalid!(:type, "must be yes_no, choice or score") if !TYPES.include?(@type)
        if !instructions.is_a?(String) || instructions.blank?
          invalid!(:instructions, "must be present")
        end
        @instructions = instructions.strip
        if !choices.nil? && @type != :choice
          invalid!(:choices, "is only allowed for choice questions")
        end
        invalid!(:levels, "is only allowed for score questions") if !levels.nil? && @type != :score
        @choices = labels(choices, :choices, 2..255) if @type == :choice
        @levels = labels(levels, :levels, 2..10) if @type == :score
      end

      private

      def labels(values, field, range)
        if !values.is_a?(Array) || !range.cover?(values.size)
          invalid!(field, "must contain #{range.first}..#{range.last} strings")
        end
        invalid!(field, "must contain strings") if !values.all?(String)
        values = values.map(&:strip)
        if values.any?(&:blank?) || values.uniq.size != values.size
          invalid!(field, "must be non-blank and unique")
        end
        values.freeze
      end

      def invalid!(field, message)
        raise InvalidRequest, "Question #{name.inspect} #{field}: #{message}"
      end
    end
  end
end
