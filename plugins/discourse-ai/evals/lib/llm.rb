# frozen_string_literal: true

class DiscourseAi::Evals::Llm
  def self.configs
    return @configs if @configs

    yaml_path = File.join(File.dirname(__FILE__), "../../config/eval-llms.yml")
    local_yaml_path = File.join(File.dirname(__FILE__), "../../config/eval-llms.local.yml")

    configs = YAML.load_file(yaml_path)["llms"] || {}
    if File.exist?(local_yaml_path)
      local_configs = YAML.load_file(local_yaml_path)["llms"] || {}
      configs = configs.merge(local_configs)
    end

    @configs = configs
  end

  def self.print
    configs
      .keys
      .map do |config_name|
        begin
          new(config_name)
        rescue StandardError
          nil
        end
      end
      .compact
      .each { |llm| puts "#{llm.config_name}: #{llm.name} (#{llm.provider})" }
  end

  def self.choose(config_name)
    return [] unless configs
    if !config_name || !configs[config_name]
      configs
        .keys
        .map do |name|
          begin
            new(name)
          rescue StandardError
            nil
          end
        end
        .compact
    else
      [new(config_name)]
    end
  end

  attr_reader :llm_model, :llm_proxy, :config_name

  def initialize(config_name)
    config = self.class.configs[config_name].dup
    if config["api_key_env"]
      api_key_env = config.delete("api_key_env")
      unless ENV[api_key_env]
        raise "Missing API key for #{config_name}, should be set via #{api_key_env}"
      end
      config[:api_key] = ENV[api_key_env]
    elsif config["api_key"]
      config[:api_key] = config.delete("api_key")
    else
      raise "No API key or API key env var configured for #{config_name}"
    end
    @llm_model = LlmModel.new(config.symbolize_keys)
    @llm_proxy = DiscourseAi::Completions::Llm.proxy(@llm_model)
    @config_name = config_name
  end

  def provider
    @llm_model.provider
  end

  def name
    @llm_model.display_name
  end

  def vision?
    @llm_model.vision_enabled
  end
end
