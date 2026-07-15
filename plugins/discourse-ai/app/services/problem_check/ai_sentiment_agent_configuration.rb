# frozen_string_literal: true

class ProblemCheck::AiSentimentAgentConfiguration < ProblemCheck
  self.priority = "high"
  self.perform_every = 1.day
  self.targets = -> do
    next [] if !SiteSetting.discourse_ai_enabled || !SiteSetting.ai_sentiment_enabled

    targets = []

    if DiscourseAi::Sentiment::PostClassification.strategy_for(:sentiment) ==
         DiscourseAi::Sentiment::Constants::AGENT_STRATEGY
      targets << "sentiment"
    end

    if DiscourseAi::Sentiment::PostClassification.strategy_for(:emotion) ==
         DiscourseAi::Sentiment::Constants::AGENT_STRATEGY
      targets << "emotion"
    end

    targets
  end

  def call
    return no_problem if !SiteSetting.discourse_ai_enabled
    return no_problem if !SiteSetting.ai_sentiment_enabled
    return no_problem if !target.in?(%w[sentiment emotion])
    if DiscourseAi::Sentiment::PostClassification.strategy_for(target) !=
         DiscourseAi::Sentiment::Constants::AGENT_STRATEGY
      return no_problem
    end

    result =
      DiscourseAi::Sentiment::AgentConfigurationValidator.validate(target, configured_agent_id)

    return no_problem if result.valid?

    details = {
      classification_type: target,
      agent_id: result.agent_id,
      agent_label: agent_label(result),
      expected_keys: result.expected_keys.join(", "),
      actual_keys:
        result.actual_keys.presence&.join(", ") ||
          I18n.t("dashboard.problem.ai_sentiment_agent_configuration_none"),
      problems: result.problems.map(&:to_s),
      url: url(result),
    }

    problem(target, override_data: details, details: details)
  end

  private

  def configured_agent_id
    if target == "sentiment"
      SiteSetting.ai_sentiment_sentiment_agent
    else
      SiteSetting.ai_sentiment_emotion_agent
    end
  end

  def agent_label(result)
    if result.agent_name.present?
      "#{ERB::Util.html_escape(result.agent_name)} (ID #{result.agent_id})"
    else
      "ID #{result.agent_id}"
    end
  end

  def url(result)
    if result.agent_name.present?
      "#{Discourse.base_path}/admin/plugins/discourse-ai/ai-agents/#{result.agent_id}/edit"
    else
      "#{Discourse.base_path}/admin/site_settings/category/all_results?filter=ai_sentiment"
    end
  end
end
