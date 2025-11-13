# frozen_string_literal: true

require_relative "../../evals/lib/llm_repository"

RSpec.describe DiscourseAi::Evals::LlmRepository do
  subject(:llm_repo) { described_class.new(configs) }

  let(:base_config) do
    {
      "display_name" => "Config Model",
      "name" => "config-model",
      "tokenizer" => "DiscourseAi::Tokenizer::OpenAiTokenizer",
      "provider" => "open_ai",
      "url" => "https://api.example.com/v1/chat/completions",
      "max_prompt_tokens" => 1_000,
      "vision_enabled" => false,
    }
  end

  let(:configs) do
    {
      "env_model" => base_config.merge("api_key_env" => "EVAL_TEST_API_KEY"),
      "static_model" => base_config.merge("display_name" => "Static Model", "api_key" => "static"),
      "invalid_model" => base_config.except("api_key_env").tap { |cfg| cfg.delete("api_key") },
    }
  end

  before { @previous_env_value = ENV["EVAL_TEST_API_KEY"] }

  after do
    if @previous_env_value
      ENV["EVAL_TEST_API_KEY"] = @previous_env_value
    else
      ENV.delete("EVAL_TEST_API_KEY")
    end
  end

  describe ".hydrate" do
    it "builds an LlmModel using the provided config and environment API key" do
      ENV["EVAL_TEST_API_KEY"] = "secret"

      model = llm_repo.hydrate("env_model")

      expect(model).to be_a(LlmModel)
      expect(model.api_key).to eq("secret")
      expect(model.display_name).to eq("Config Model")
    end

    it "uses the static API key when present" do
      model = llm_repo.hydrate("static_model")

      expect(model.api_key).to eq("static")
    end

    it "raises when no API key information is configured" do
      expect { llm_repo.hydrate("invalid_model") }.to raise_error(
        RuntimeError,
        "No API key or API key env var configured for invalid_model",
      )
    end
  end

  describe ".choose" do
    it "returns hydrated models for all configs when none specified" do
      ENV["EVAL_TEST_API_KEY"] = "secret"

      models = llm_repo.choose(nil)

      expect(models.map(&:display_name)).to contain_exactly("Config Model", "Static Model")
    end

    it "returns the requested model when the config exists" do
      model = llm_repo.choose("static_model").first

      expect(model.display_name).to eq("Static Model")
    end

    it "returns hydrated models for comma separated config names" do
      ENV["EVAL_TEST_API_KEY"] = "secret"

      models = llm_repo.choose("static_model,env_model")

      expect(models.map(&:display_name)).to eq(["Static Model", "Config Model"])
    end

    it "returns an empty array when any provided config name is unknown" do
      expect(llm_repo.choose("static_model,unknown")).to eq([])
    end

    it "returns an empty array when the config name is unknown" do
      expect(llm_repo.choose("unknown")).to eq([])
    end
  end

  describe ".available_models" do
    it "skips configs that cannot be hydrated" do
      models = llm_repo.choose(nil)

      expect(models.map(&:display_name)).to contain_exactly("Static Model")
    end
  end
end
