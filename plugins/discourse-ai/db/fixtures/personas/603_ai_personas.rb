# frozen_string_literal: true

summarization_personas = [DiscourseAi::Personas::Summarizer, DiscourseAi::Personas::ShortSummarizer]

def from_setting(setting_name)
  DB
    .query_single(
      "SELECT value FROM site_settings WHERE name = :setting_name",
      setting_name: setting_name,
    )
    &.first
    &.split("|")
end

DiscourseAi::Personas::Persona.system_personas.each do |persona_class, id|
  persona = AiPersona.find_by(id: id)
  if !persona
    persona = AiPersona.new
    persona.id = id

    if persona_class == DiscourseAi::Personas::WebArtifactCreator
      # this is somewhat sensitive, so we default it to staff
      persona.allowed_group_ids = [Group::AUTO_GROUPS[:staff]]
    elsif summarization_personas.include?(persona_class)
      # Copy group permissions from site settings.
      default_groups = [Group::AUTO_GROUPS[:staff], Group::AUTO_GROUPS[:trust_level_3]]

      setting_name = "ai_custom_summarization_allowed_groups"
      if persona_class == DiscourseAi::Personas::ShortSummarizer
        setting_name = "ai_summary_gists_allowed_groups"
        default_groups = [Group::AUTO_GROUPS[:everyone]]
      end

      persona.allowed_group_ids = from_setting(setting_name) || default_groups
    elsif persona_class == DiscourseAi::Personas::CustomPrompt
      setting_name = "ai_helper_custom_prompts_allowed_groups"
      default_groups = [Group::AUTO_GROUPS[:staff]]
      persona.allowed_group_ids = from_setting(setting_name) || default_groups
    elsif persona_class == DiscourseAi::Personas::ContentCreator
      persona.allowed_group_ids = [Group::AUTO_GROUPS[:everyone]]
    else
      persona.allowed_group_ids = [Group::AUTO_GROUPS[:trust_level_0]]
    end

    persona.enabled = persona_class.default_enabled
    persona.priority = true if persona_class == DiscourseAi::Personas::General
  end

  names = [
    persona_class.name,
    persona_class.name + " 1",
    persona_class.name + " 2",
    persona_class.name + SecureRandom.hex,
  ]
  persona.name = DB.query_single(<<~SQL, names, id).first
    SELECT guess_name
    FROM (
      SELECT unnest(Array[?]) AS guess_name
      FROM (SELECT 1) as t
    ) x
    LEFT JOIN ai_personas ON ai_personas.name = x.guess_name AND ai_personas.id <> ?
    WHERE ai_personas.id IS NULL
    ORDER BY x.guess_name ASC
    LIMIT 1
  SQL

  persona.description = persona_class.description

  persona.system = true
  instance = persona_class.new
  tools = {}
  instance.tools.map { |tool| tool.to_s.split("::").last }.each { |name| tools[name] = nil }
  existing_tools = persona.tools || []

  existing_tools.each do |tool|
    if tool.is_a?(Array)
      name, value = tool
      tools[name] = value if tools.key?(name)
    end
  end

  forced_tool_names = instance.force_tool_use.map { |tool| tool.to_s.split("::").last }
  persona.tools = tools.map { |name, value| [name, value, forced_tool_names.include?(name)] }
  persona.forced_tool_count = instance.forced_tool_count

  persona.response_format = instance.response_format
  persona.examples = instance.examples

  persona.system_prompt = instance.system_prompt
  persona.top_p = instance.top_p
  persona.temperature = instance.temperature
  persona.save!(validate: false)
end
