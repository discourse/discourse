# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class Option
        attr_reader :tool, :name, :type, :values, :default

        def initialize(tool:, name:, type:, values: nil, default: nil)
          @tool = tool
          @name = name.to_s
          @type = type
          @values = values
          @default = default
        end

        def localized_name
          I18n.t("discourse_ai.ai_bot.tool_options.#{tool.signature[:name]}.#{name}.name")
        end

        def localized_description
          I18n.t("discourse_ai.ai_bot.tool_options.#{tool.signature[:name]}.#{name}.description")
        end
      end
    end
  end
end
