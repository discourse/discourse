# frozen_string_literal: true

module DiscourseAi
  module Evals
    module Runners
      class Base
        class << self
          def can_handle?(_feature)
            raise NotImplemented
          end

          def find_runner(feature)
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
            klass&.new(feature.split(":").last) if klass
          end
        end

        attr_reader :feature

        def initialize(feature)
          @feature = feature
        end

        private

        def resolve_persona(persona_class: nil)
          persona_id ||=
            DiscourseAi::Personas::Persona.system_personas[persona_class] if persona_class
          persona_record = persona_id && AiPersona.find_by_id_from_cache(persona_id)

          persona_klass = persona_record&.class_instance || persona_class

          if persona_klass.nil?
            raise ArgumentError, "Unable to resolve persona for runner (#{self.class.name})"
          end

          persona_klass.new
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
              append_structured_chunk(accumulator, schema_type, chunk)
            elsif type.blank?
              append_structured_chunk(accumulator, schema_type, partial)
            end
          end

          accumulator
        end

        def append_structured_chunk(accumulator, schema_type, chunk)
          return if chunk.nil? || (chunk.respond_to?(:empty?) && chunk.empty?)

          case schema_type
          when "array"
            Array(chunk).each { |item| accumulator << item if accumulator.exclude?(item) }
          else
            accumulator << chunk.to_s
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
