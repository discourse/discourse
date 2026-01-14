# frozen_string_literal: true

module DiscourseAi
  module Evals
    class LlmRepository
      def initialize(configs = nil)
        @configs = configs
      end

      def print
        configs.each do |config_name, attrs|
          puts "#{config_name}: #{attrs["display_name"]} (#{attrs["provider"]})"
        end
      end

      def choose(config_name)
        return [] unless configs

        return all_available_models if config_name.nil? || config_name == ""

        names = config_name.split(",").map(&:strip).reject(&:empty?)

        return all_available_models if names.empty?

        models = []
        names.each do |name|
          return [] unless configs.key?(name)

          models << hydrate(name)
        end

        models
      end

      def hydrate(config_name)
        config = configs.fetch(config_name) { raise KeyError, "Unknown model '#{config_name}'" }
        build_model(config_name, config)
      end

      private

      def all_available_models
        configs.keys.filter_map do |config_name|
          begin
            hydrate(config_name)
          rescue => e
            puts "Failed to hydrate #{config_name}: #{e.message}" unless Rails.env.test?
            nil
          end
        end
      end

      def configs
        @configs ||= load_configs
      end

      def load_configs
        yaml_path = File.join(File.dirname(__FILE__), "../../config/eval-llms.yml")
        local_yaml_path = File.join(File.dirname(__FILE__), "../../config/eval-llms.local.yml")

        configs = YAML.load_file(yaml_path)["llms"] || {}
        if File.exist?(local_yaml_path)
          local_configs = YAML.load_file(local_yaml_path)["llms"] || {}
          configs = configs.merge(local_configs)
        end

        configs
      end

      def build_model(config_name, config)
        config = config.deep_dup

        api_key =
          if (api_key_env = config.delete("api_key_env"))
            ENV[api_key_env] ||
              raise("Missing API key for #{config_name}, should be set via #{api_key_env}")
          elsif config.key?("api_key")
            config.delete("api_key")
          else
            raise "No API key or API key env var configured for #{config_name}"
          end

        attributes = config.symbolize_keys
        attributes[:api_key] = api_key

        LlmModel.new(attributes)
      end
    end
  end
end
