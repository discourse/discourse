# frozen_string_literal: true

module DiscourseAi
  module Evals
    class PersonaPromptLoader
      PERSONA_GLOB = File.join(__dir__, "../personas/**/*.yml")

      def list
        entries.map { |entry| [entry[:key], entry[:description]] }
      end

      def find_prompt(key)
        entry = entries.find { |definition| definition[:key] == key }
        entry&.dig(:system_prompt).presence
      end

      private

      def entries
        @entries ||= Dir.glob(PERSONA_GLOB).sort.map { |path| load_entry(path) }.compact
      end

      def load_entry(path)
        yaml = YAML.load_file(path) || {}

        key = yaml["key"].presence || File.basename(path, ".yml")
        system_prompt = yaml["system_prompt"].to_s

        return nil if key.blank? || system_prompt.blank?

        { key: key.to_s, system_prompt: system_prompt, description: yaml["description"] }
      rescue Psych::SyntaxError => e
        warn "Warning: failed to load persona prompt from #{path}: #{e.message}"
        nil
      end
    end
  end
end
