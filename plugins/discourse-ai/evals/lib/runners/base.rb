# frozen_string_literal: true

module DiscourseAi
  module Evals
    module Runners
      class Base
        class << self
          def can_handle?(_feature)
            raise NotImplemented
          end

          def find_runner(feature, persona_prompt)
            registry = [
              DiscourseAi::Evals::Runners::AiHelper,
              DiscourseAi::Evals::Runners::Translation,
              DiscourseAi::Evals::Runners::Hyde,
              DiscourseAi::Evals::Runners::Discoveries,
              DiscourseAi::Evals::Runners::Spam,
              DiscourseAi::Evals::Runners::Summarization,
              DiscourseAi::Evals::Runners::Inference,
            ]
            klass = registry.find { |runner| runner.can_handle?(feature) }
            klass&.new(feature.split(":").last, persona_prompt) if klass
          end
        end

        attr_reader :feature_name, :persona_prompt_override

        def initialize(feature, persona_prompt_override = nil)
          @feature_name = feature
          @persona_prompt_override = persona_prompt_override
        end

        private

        def resolve_persona(persona_class: nil)
          if persona_class.nil?
            raise ArgumentError, "Unable to resolve persona for runner (#{self.class.name})"
          end

          persona = persona_class.new

          if persona_prompt_override.present?
            override = persona_prompt_override
            persona.define_singleton_method(:system_prompt) { override }
          end

          persona
        end

        def capture_plain_response(bot, context)
          buffer = +""
          bot.reply(context) { |partial, _, type| buffer << partial if type.blank? }
          buffer
        end

        def capture_structured_response(bot, context, schema_key:, schema_type: "string")
          key = schema_key&.to_sym
          raise ArgumentError, "schema_key is required for structured capture" if key.nil?

          accumulator = schema_type == "array" ? [] : +""

          bot.reply(context) do |partial, _, type|
            if type == :structured_output
              chunk = partial.read_buffered_property(key)
              accumulator = append_structured_chunk(accumulator, schema_type, chunk)
            elsif type.blank?
              accumulator = append_structured_chunk(accumulator, schema_type, partial)
            end
          end

          accumulator
        end

        def append_structured_chunk(accumulator, schema_type, chunk)
          return accumulator if chunk.nil? || (chunk.respond_to?(:empty?) && chunk.empty?)

          case schema_type
          when "array"
            Array(chunk).each { |item| accumulator << item if accumulator.exclude?(item) }
            accumulator
          when "string"
            accumulator << chunk.to_s
          else
            chunk
          end
        end

        def wrap_result(raw, metadata = nil)
          metadata = metadata&.compact
          metadata.present? ? { raw:, metadata: metadata } : { raw: raw }
        end
      end
    end
  end
end
