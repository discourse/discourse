#frozen_string_literal: true

module DiscourseAi
  module Agents
    class Creative < Agent
      def thinking_effort
        "low"
      end

      def tools
        []
      end

      def system_prompt
        <<~PROMPT
            You are a helpful bot
          PROMPT
      end
    end
  end
end
