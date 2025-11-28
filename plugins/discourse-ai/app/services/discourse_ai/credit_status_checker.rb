# frozen_string_literal: true

module DiscourseAi
  class CreditStatusChecker
    include Service::Base

    CACHE_TTL = 5.seconds

    params do
      attribute :persona_ids, :array, default: []
      attribute :features, :array, default: []
      attribute :llm_model_ids, :array, default: []

      validates :persona_ids, length: { maximum: 100 }
      validates :features, length: { maximum: 100 }
      validates :llm_model_ids, length: { maximum: 100 }

      before_validation do
        self.persona_ids = Array(persona_ids).compact.map(&:to_i).uniq
        self.features = Array(features).compact.map(&:to_s).uniq
        self.llm_model_ids = Array(llm_model_ids).compact.map(&:to_i).uniq
      end
    end

    step :check_personas
    step :check_features
    step :check_llm_models

    private

    def check_personas(params:)
      context[:personas] = {}
      return true if params.persona_ids.blank?

      # Batch load personas
      personas = AiPersona.where(id: params.persona_ids).to_a

      # Collect all LLM model IDs needed
      llm_model_ids =
        personas.map { |p| p.default_llm_id || SiteSetting.ai_default_llm_model }.compact.uniq

      # Batch load LLM models with their credit allocations
      llm_models = LlmModel.where(id: llm_model_ids).includes(:llm_credit_allocation).index_by(&:id)

      personas.each do |persona|
        llm_model_id = persona.default_llm_id || SiteSetting.ai_default_llm_model
        llm_model = llm_models[llm_model_id]
        next unless llm_model&.credit_system_enabled?

        context[:personas][persona.id] = {
          llm_model_id: llm_model.id,
          credit_status: cached_credit_status(llm_model),
        }
      end

      true
    end

    def check_features(params:)
      context[:features] = {}
      return true if params.features.blank?

      # Collect all LLM model IDs from features
      llm_model_ids = []
      features_with_models = {}

      params.features.each do |feature_name|
        feature = DiscourseAi::Configuration::Feature.all.find { |f| f.name == feature_name }
        next unless feature

        llm_models = feature.llm_models
        next if llm_models.blank?

        llm_model = llm_models.first
        llm_model_ids << llm_model.id if llm_model
        features_with_models[feature_name] = llm_model.id if llm_model
      end

      # Batch load all LLM models
      llm_models =
        LlmModel
          .where(id: llm_model_ids.compact.uniq)
          .includes(:llm_credit_allocation)
          .index_by(&:id)

      features_with_models.each do |feature_name, llm_model_id|
        llm_model = llm_models[llm_model_id]
        next unless llm_model&.credit_system_enabled?

        context[:features][feature_name] = {
          llm_model_id: llm_model.id,
          credit_status: cached_credit_status(llm_model),
        }
      end

      true
    end

    def check_llm_models(params:)
      context[:llm_models] = {}
      return true if params.llm_model_ids.blank?

      # Batch load LLM models with their credit allocations
      llm_models =
        LlmModel.where(id: params.llm_model_ids).includes(:llm_credit_allocation).index_by(&:id)

      params.llm_model_ids.each do |id|
        llm_model = llm_models[id]
        next unless llm_model&.credit_system_enabled?

        context[:llm_models][id] = { credit_status: cached_credit_status(llm_model) }
      end

      true
    end

    def cached_credit_status(llm_model)
      cache_key = "discourse_ai:credit_status:v1:llm_model:#{llm_model.id}"

      Discourse.cache.fetch(cache_key, expires_in: CACHE_TTL) { serialize_credit_status(llm_model) }
    end

    def serialize_credit_status(llm_model)
      allocation = llm_model.llm_credit_allocation
      return { available: true } unless allocation

      {
        available: !allocation.hard_limit_reached?,
        hard_limit_reached: allocation.hard_limit_reached?,
        credits_remaining: allocation.credits_remaining,
        daily_credits: allocation.daily_credits,
        percentage_remaining: allocation.percentage_remaining,
        next_reset_at: allocation.next_reset_at&.iso8601,
        reset_time_relative: allocation.relative_reset_time,
        reset_time_formatted: allocation.formatted_reset_time,
      }
    end
  end
end
