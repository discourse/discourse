# frozen_string_literal: true

class AiSpamSerializer < ApplicationSerializer
  attributes :is_enabled,
             :llm_id,
             :custom_instructions,
             :available_llms,
             :stats,
             :flagging_username,
             :spam_score_type,
             :spam_scanning_user,
             :ai_persona_id,
             :available_personas

  def is_enabled
    object[:enabled]
  end

  def llm_id
    settings&.llm_model&.id
  end

  def ai_persona_id
    settings&.ai_persona&.id ||
      DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::SpamDetector]
  end

  def custom_instructions
    settings&.custom_instructions
  end

  def available_llms
    DiscourseAi::Configuration::LlmEnumerator
      .values(allowed_seeded_llms: SiteSetting.ai_spam_detection_model_allowed_seeded_models_map)
      .map { |hash| { id: hash[:value], name: hash[:name] } }
  end

  def available_personas
    DiscourseAi::Configuration::PersonaEnumerator.values.map do |h|
      { id: h[:value], name: h[:name] }
    end
  end

  def flagging_username
    object[:flagging_username]
  end

  def spam_score_type
    ReviewableScore.types[:spam]
  end

  def stats
    {
      scanned_count: object[:stats].scanned_count.to_i,
      spam_detected: object[:stats].spam_detected.to_i,
      false_positives: object[:stats].false_positives.to_i,
      false_negatives: object[:stats].false_negatives.to_i,
    }
  end

  def settings
    object[:settings]
  end

  def spam_scanning_user
    user = DiscourseAi::AiModeration::SpamScanner.flagging_user

    user.serializable_hash(only: %i[id username name admin]) if user.present?
  end
end
