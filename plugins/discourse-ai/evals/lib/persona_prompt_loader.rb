# frozen_string_literal: true

require "yaml"

module DiscourseAi
  module Evals
    class PersonaPromptLoader
      DEFAULT_PERSONA_KEY = "default"
      PERSONA_GLOB = File.join(__dir__, "../personas/**/*.yml")

      def list
        entries.map { |entry| [entry[:key], entry[:description]] }
      end

      def find_prompt(key)
        entry = entries.find { |definition| definition[:key] == key }
        entry && entry[:system_prompt]
      end

      def entries
        @entries ||= Dir.glob(PERSONA_GLOB).sort.map { |path| load_entry(path) }.compact
      end

      def load_entry(path)
        yaml = YAML.load_file(path) || {}

        key = yaml["key"]
        key = File.basename(path, ".yml") if key.nil? || key.to_s.strip.empty?
        return nil if key.nil?

        system_prompt = yaml["system_prompt"]
        system_prompt = system_prompt.to_s
        return nil if system_prompt.strip.empty?

        description = yaml["description"]
        description = description.to_s.strip
        description = nil if description.empty?

        { key: key.to_s.strip, system_prompt: system_prompt, description: description }
      rescue Psych::SyntaxError => e
        warn "Warning: failed to load persona prompt from #{path}: #{e.message}"
        nil
      end
    end
  end
end
