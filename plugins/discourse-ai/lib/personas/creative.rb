#frozen_string_literal: true

module DiscourseAi
  module Personas
    class Creative < Persona
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
