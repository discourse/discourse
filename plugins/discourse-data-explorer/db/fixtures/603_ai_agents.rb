# frozen_string_literal: true

return unless defined?(DiscourseAi)

reserved = DiscourseAi::Agents::Agent::RESERVED_EXTERNAL_IDS[:data_explorer]
return if reserved.nil?

Dir[File.join(__dir__, "../../lib/discourse_data_explorer/tools/*.rb")].each do |f|
  require_relative f
end
require_relative "../../lib/discourse_data_explorer/ai_query_generator"

# map feature names to agent classes
# add new entries here when registering additional AI features
feature_agents = { query_generation: DiscourseDataExplorer::AiQueryGenerator }

reserved[:features].each do |feature_name, feature_config|
  klass = feature_agents[feature_name]
  next if klass.nil?

  agent_id = feature_config[:agent_id]
  agent = AiAgent.find_by(id: agent_id)
  if agent.nil?
    agent = AiAgent.new(id: agent_id)
    agent.system = true
    agent.enabled = true
    agent.allowed_group_ids = [Group::AUTO_GROUPS[:staff]]
  end

  next unless agent.system

  instance = klass.new
  agent.name = klass.name
  agent.description = klass.description
  agent.system_prompt = instance.system_prompt
  agent.tools = instance.tools.map { |t| [t.to_s.split("::").last, nil, false] }
  agent.temperature = instance.temperature
  agent.save!(validate: false)
end
