# frozen_string_literal: true

require "yaml"

module DiscourseAi
  module Evals
    class AgentPromptLoader
      DEFAULT_AGENT_KEY = "default"
      AGENT_GLOB = File.join(__dir__, "../agents/**/*.yml")

      def list
        entries.map { |entry| [entry[:key], entry[:description]] }
      end

      def find_prompt(key)
        entry = entries.find { |definition| definition[:key] == key }
        entry && entry[:system_prompt]
      end

      def entries
        @entries ||= Dir.glob(AGENT_GLOB).sort.map { |path| load_entry(path) }.compact
      end

      def variants_for(keys, comparison_mode: nil)
        keys_array = Array(keys)
        variants = []

        if keys_array.empty? || comparison_mode == :agents
          variants << { key: DEFAULT_AGENT_KEY, prompt: nil }
        end

        keys_array.each do |key|
          next if key == DEFAULT_AGENT_KEY

          prompt = find_prompt(key)
          if prompt.to_s.strip.empty?
            puts "Error: Unknown agent key '#{key}'. Run --list-agents to view options."
            exit 1
          end

          variants << { key: key, prompt: prompt }
        end

        variants
      end

      def print(output: $stdout)
        output.puts("#{DEFAULT_AGENT_KEY}: built-in agent prompt")
        list.each do |key, description|
          if description && !description.empty?
            output.puts("#{key}: #{description}")
          else
            output.puts(key)
          end
        end
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
        warn "Warning: failed to load agent prompt from #{path}: #{e.message}"
        nil
      end
    end
  end
end
