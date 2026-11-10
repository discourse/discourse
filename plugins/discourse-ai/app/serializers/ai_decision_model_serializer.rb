# frozen_string_literal: true

class AiDecisionModelSerializer < ApplicationSerializer
  root "ai_decision_model"

  attributes :id,
             :display_name,
             :name,
             :provider,
             :url,
             :ai_secret_id,
             :vision_enabled,
             :custom_headers,
             :seeded

  # The allocation exposes the fields the credit bar reads, so it shares the LLM serializer.
  has_one :decision_model_credit_allocation,
          key: :credit_allocation,
          serializer: LlmCreditAllocationSerializer,
          embed: :object,
          if: :include_credit_allocation?

  def url
    object.seeded? ? "********" : object.url
  end

  def seeded
    object.seeded?
  end

  def include_custom_headers?
    scope&.is_admin? && !object.seeded?
  end

  def include_credit_allocation?
    object.credit_system_enabled?
  end
end
