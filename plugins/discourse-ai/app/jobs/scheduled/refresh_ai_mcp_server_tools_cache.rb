# frozen_string_literal: true

module Jobs
  class RefreshAiMcpServerToolsCache < ::Jobs::Scheduled
    every 1.hour

    def execute(args)
      AiMcpServer
        .where(enabled: true)
        .find_each do |server|
          DiscourseAi::Mcp::ToolRegistry.refresh!(server, raise_on_error: false)
        end
    end
  end
end
