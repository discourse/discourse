# frozen_string_literal: true

summarization_agents = [DiscourseAi::Agents::Summarizer, DiscourseAi::Agents::ShortSummarizer]

def from_setting(setting_name)
  DB
    .query_single(
      "SELECT value FROM site_settings WHERE name = :setting_name",
      setting_name: setting_name,
    )
    &.first
    &.split("|")
end

DiscourseAi::Agents::Agent.system_agents.each do |agent_class, id|
  agent = AiAgent.find_by(id: id)
  if !agent
    agent = AiAgent.new
    agent.id = id

    if agent_class == DiscourseAi::Agents::WebArtifactCreator
      # this is somewhat sensitive, so we default it to staff
      agent.allowed_group_ids = [Group::AUTO_GROUPS[:staff]]
    elsif summarization_agents.include?(agent_class)
      # Copy group permissions from site settings.
      default_groups = [Group::AUTO_GROUPS[:staff], Group::AUTO_GROUPS[:trust_level_1]]

      setting_name = "ai_custom_summarization_allowed_groups"
      if agent_class == DiscourseAi::Agents::ShortSummarizer
        setting_name = "ai_summary_gists_allowed_groups"
        default_groups = [Group::AUTO_GROUPS[:everyone]]
      end

      agent.allowed_group_ids = from_setting(setting_name) || default_groups
    elsif agent_class == DiscourseAi::Agents::CustomPrompt
      setting_name = "ai_helper_custom_prompts_allowed_groups"
      default_groups = [Group::AUTO_GROUPS[:staff]]
      agent.allowed_group_ids = from_setting(setting_name) || default_groups
    elsif agent_class == DiscourseAi::Agents::ContentCreator
      agent.allowed_group_ids = [Group::AUTO_GROUPS[:everyone]]
    else
      agent.allowed_group_ids = [Group::AUTO_GROUPS[:trust_level_0]]
    end

    agent.enabled = agent_class.default_enabled
    agent.priority = true if agent_class == DiscourseAi::Agents::General
  end

  names = [
    agent_class.name,
    agent_class.name + " 1",
    agent_class.name + " 2",
    agent_class.name + SecureRandom.hex,
  ]
  agent.name = DB.query_single(<<~SQL, names, id).first
    SELECT guess_name
    FROM (
      SELECT unnest(Array[?]) AS guess_name
      FROM (SELECT 1) as t
    ) x
    LEFT JOIN ai_agents ON ai_agents.name = x.guess_name AND ai_agents.id <> ?
    WHERE ai_agents.id IS NULL
    ORDER BY x.guess_name ASC
    LIMIT 1
  SQL

  agent.description = agent_class.description

  agent.system = true
  instance = agent_class.new
  tools = {}
  instance.tools.map { |tool| tool.to_s.split("::").last }.each { |name| tools[name] = nil }
  existing_tools = agent.tools || []

  existing_tools.each do |tool|
    if tool.is_a?(Array)
      name, value = tool
      tools[name] = value if tools.key?(name)
    end
  end

  forced_tool_names = instance.force_tool_use.map { |tool| tool.to_s.split("::").last }
  agent.tools = tools.map { |name, value| [name, value, forced_tool_names.include?(name)] }
  agent.forced_tool_count = instance.forced_tool_count

  agent.response_format = instance.response_format
  agent.examples = instance.examples

  agent.system_prompt = instance.system_prompt
  agent.top_p = instance.top_p
  agent.temperature = instance.temperature
  agent.save!(validate: false)
end
