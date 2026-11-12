# frozen_string_literal: true

module Jobs
  class RefreshAiMcpServerTools < ::Jobs::Base
    def execute(args)
      server = AiMcpServer.find_by(id: args[:ai_mcp_server_id])
      return if server.blank? || !server.enabled?

      DiscourseAi::Mcp::ToolRegistry.refresh!(server, raise_on_error: false)
    end
  end
end
