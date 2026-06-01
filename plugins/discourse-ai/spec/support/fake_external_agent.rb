# frozen_string_literal: true

module DiscourseAi
  module TestHelpers
    class FakeExternalAgent < DiscourseAi::Agents::Agent
      def tools
        []
      end

      def system_prompt
        "Test agent"
      end
    end
  end
end
