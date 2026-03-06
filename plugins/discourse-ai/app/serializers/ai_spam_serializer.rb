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
             :ai_agent_id,
             :available_agents

  def is_enabled
    object[:enabled]
  end

  def llm_id
    settings&.llm_model&.id
  end

  def ai_agent_id
    settings&.ai_agent_id || settings&.ai_agent&.id ||
      DiscourseAi::Agents::Agent.system_agents[DiscourseAi::Agents::SpamDetector]
  end

  def custom_instructions
    settings&.custom_instructions
  end

  def available_llms
    DiscourseAi::Configuration::LlmEnumerator.values.map do |hash|
      { id: hash[:value], name: hash[:name] }
    end
  end

  def available_agents
    DiscourseAi::Configuration::AgentEnumerator.values.map { |h| { id: h[:value], name: h[:name] } }
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
