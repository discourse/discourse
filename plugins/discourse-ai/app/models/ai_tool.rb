# frozen_string_literal: true

class AiTool < ActiveRecord::Base
  validates :name, presence: true, length: { maximum: 100 }, uniqueness: true
  validates :tool_name, presence: true, length: { maximum: 100 }
  validates :description, presence: true, length: { maximum: 1000 }
  validates :summary, presence: true, length: { maximum: 255 }
  validates :script, presence: true, length: { maximum: 100_000 }
  validates :created_by_id, presence: true
  belongs_to :created_by, class_name: "User"
  belongs_to :rag_llm_model, class_name: "LlmModel"
  has_many :rag_document_fragments, dependent: :destroy, as: :target
  has_many :upload_references, as: :target, dependent: :destroy
  has_many :uploads, through: :upload_references
  before_save :set_image_generation_tool_flag
  before_update :regenerate_rag_fragments

  ALPHANUMERIC_PATTERN = /\A[a-zA-Z0-9_]+\z/

  validates :tool_name,
            format: {
              with: ALPHANUMERIC_PATTERN,
              message: I18n.t("discourse_ai.tools.name.characters"),
            }

  validate :validate_parameters_enum

  def signature
    {
      name: function_call_name,
      description: description,
      parameters: parameters.map(&:symbolize_keys),
    }
  end

  # Backwards compatibility: if tool_name is not set (existing custom tools), use name
  def function_call_name
    tool_name.presence || name
  end

  def runner(parameters, llm:, bot_user:, context: nil)
    DiscourseAi::Personas::ToolRunner.new(
      parameters: parameters,
      llm: llm,
      bot_user: bot_user,
      context: context,
      tool: self,
    )
  end

  after_commit :bump_persona_cache

  def bump_persona_cache
    AiPersona.persona_cache.flush!
  end

  def regenerate_rag_fragments
    if rag_chunk_tokens_changed? || rag_chunk_overlap_tokens_changed?
      RagDocumentFragment.where(target: self).delete_all
    end
  end

  def image_generation_tool?
    is_image_generation_tool
  end

  private

  def set_image_generation_tool_flag
    has_prompt_parameter = parameters.is_a?(Array) && parameters.any? { |p| p["name"] == "prompt" }
    has_upload_create = script.include?("upload.create")
    has_chain_set_custom_raw = script.include?("chain.setCustomRaw")

    self.is_image_generation_tool =
      has_prompt_parameter && has_upload_create && has_chain_set_custom_raw
  end

  def validate_parameters_enum
    return unless parameters.is_a?(Array)

    parameters.each_with_index do |param, index|
      next if !param.is_a?(Hash) || !param.key?("enum")
      enum_values = param["enum"]

      if enum_values.empty?
        errors.add(
          :parameters,
          "Parameter '#{param["name"]}' at index #{index}: enum cannot be empty",
        )
        next
      end

      if enum_values.uniq.length != enum_values.length
        errors.add(
          :parameters,
          "Parameter '#{param["name"]}' at index #{index}: enum values must be unique",
        )
      end
    end
  end

  # Load a JavaScript file from the ai_tool_scripts directory
  def self.load_script(filename)
    path = File.join(__dir__, "../../lib/ai_tool_scripts", filename)
    File.read(path)
  end

  def self.preamble
    load_script("preamble.js")
  end

  def self.presets
    (
      [
        {
          preset_id: "browse_web_jina",
          name: "Browse Web",
          tool_name: "browse_web",
          description: "Browse the web as a markdown document",
          parameters: [
            { name: "url", type: "string", required: true, description: "The URL to browse" },
          ],
          script: "#{preamble}\n#{load_script("presets/browse_web_jina.js")}",
        },
        {
          preset_id: "exchange_rate",
          name: "Exchange Rate",
          tool_name: "exchange_rate",
          description: "Get current exchange rates for various currencies",
          parameters: [
            {
              name: "base_currency",
              type: "string",
              required: true,
              description: "The base currency code (e.g., USD, EUR)",
            },
            {
              name: "target_currency",
              type: "string",
              required: true,
              description: "The target currency code (e.g., EUR, JPY)",
            },
            { name: "amount", type: "number", description: "Amount to convert eg: 123.45" },
          ],
          script: "#{preamble}\n#{load_script("presets/exchange_rate.js")}",
          summary: "Get current exchange rates between two currencies",
        },
        {
          preset_id: "stock_quote",
          name: "Stock Quote (AlphaVantage)",
          tool_name: "stock_quote",
          description: "Get real-time stock quote information using AlphaVantage API",
          parameters: [
            {
              name: "symbol",
              type: "string",
              required: true,
              description: "The stock symbol (e.g., AAPL, GOOGL)",
            },
          ],
          script: "#{preamble}\n#{load_script("presets/stock_quote.js")}",
          summary: "Get real-time stock quotes using AlphaVantage API",
        },
      ] + image_generation_presets +
        [
          {
            preset_id: "empty_tool",
            script: "#{preamble}\n#{load_script("presets/empty_tool.js")}",
          },
        ]
    ).map do |preset|
      preset[:preset_name] = I18n.t("discourse_ai.tools.presets.#{preset[:preset_id]}.name")
      preset
    end
  end

  def self.image_generation_presets
    [
      { preset_id: "image_generation_category", is_category: true, category: "image_generation" },
      {
        preset_id: "image_generation_custom",
        name: "Custom",
        tool_name: "image_generation_custom",
        description: "Configure a custom image generation API",
        parameters: [
          {
            name: "prompt",
            type: "string",
            required: true,
            description: "The text prompt for image generation",
          },
        ],
        script: "#{preamble}\n#{load_script("presets/image_generation/custom.js")}",
        summary: "Custom image generation",
        category: "image_generation",
      },
      {
        preset_id: "image_generation_openai",
        name: "GPT Image",
        provider: "OpenAI",
        model_name: "GPT Image 1",
        tool_name: "image_generation_openai",
        description: "Generate images using OpenAI's GPT Image 1 model",
        parameters: [
          {
            name: "prompt",
            type: "string",
            required: true,
            description: "The text prompt for image generation",
          },
          {
            name: "size",
            type: "string",
            required: false,
            description: "Image size (1024x1024, 1792x1024, or 1024x1792)",
          },
        ],
        script: "#{preamble}\n#{load_script("presets/image_generation/openai.js")}",
        summary: "Generate images with OpenAI GPT Image 1 model",
        category: "image_generation",
      },
      {
        preset_id: "image_generation_gemini",
        name: "Nano Banana",
        provider: "Google Nano Banana",
        model_name: "Gemini 2.5 Flash Image",
        tool_name: "image_generation_gemini",
        description: "Generate images using Gemini 2.5 Flash Image (Nano Banana)",
        parameters: [
          {
            name: "prompt",
            type: "string",
            required: true,
            description: "The text prompt for image generation",
          },
        ],
        script: "#{preamble}\n#{load_script("presets/image_generation/gemini.js")}",
        summary: "Generate images with Gemini 2.5 Flash Image",
        category: "image_generation",
      },
      {
        preset_id: "image_generation_flux",
        name: "FLUX",
        provider: "Together.ai",
        model_name: "FLUX 1.1",
        tool_name: "image_generation",
        description:
          "Generate images using the FLUX 1.1 Pro model from Black Forest Labs via Together.ai",
        parameters: [
          {
            name: "prompt",
            type: "string",
            required: true,
            description: "The text prompt for image generation",
          },
          {
            name: "seed",
            type: "number",
            required: false,
            description: "Optional seed for random number generation",
          },
        ],
        script: "#{preamble}\n#{load_script("presets/image_generation/flux.js")}",
        summary: "Generate images with FLUX 1.1 Pro",
        category: "image_generation",
      },
    ]
  end
end

# == Schema Information
#
# Table name: ai_tools
#
#  id                       :bigint           not null, primary key
#  description              :string           not null
#  enabled                  :boolean          default(TRUE), not null
#  is_image_generation_tool :boolean          default(FALSE), not null
#  name                     :string           not null
#  parameters               :jsonb            not null
#  rag_chunk_overlap_tokens :integer          default(10), not null
#  rag_chunk_tokens         :integer          default(374), not null
#  script                   :text             not null
#  summary                  :string           not null
#  tool_name                :string(100)      default(""), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  created_by_id            :integer          not null
#  rag_llm_model_id         :bigint
#
