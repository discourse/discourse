# frozen_string_literal: true

class DisableNativeStructuredOutputForOldClaudeModels < ActiveRecord::Migration[7.2]
  def up
    # Native structured output (output_config.format) is only supported on Claude 4+ models.
    # Set the disable flag for all existing old Claude models so they fall back to assistant
    # message prefilling for JSON output.
    execute <<~SQL
      UPDATE llm_models
      SET provider_params = COALESCE(provider_params, '{}'::jsonb) || '{"disable_native_structured_output": true}'::jsonb
      WHERE provider IN ('anthropic', 'aws_bedrock')
        AND (
          name LIKE 'claude-2%'
          OR name LIKE 'claude-instant%'
          OR name LIKE 'claude-3-%'
          OR name LIKE 'claude-3.%'
          OR name LIKE 'anthropic.claude-v2%'
          OR name LIKE 'anthropic.claude-instant%'
          OR name LIKE 'anthropic.claude-3-%'
        )
    SQL
  end

  def down
    execute <<~SQL
      UPDATE llm_models
      SET provider_params = provider_params - 'disable_native_structured_output'
      WHERE provider IN ('anthropic', 'aws_bedrock')
    SQL
  end
end
