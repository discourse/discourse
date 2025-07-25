# frozen_string_literal: true

Discourse::Application.routes.append do
  mount ::DiscourseChatIntegration::AdminEngine,
        at: "/admin/plugins/chat-integration",
        constraints: AdminConstraint.new
  mount ::DiscourseChatIntegration::PublicEngine, at: "/chat-transcript/", as: "chat-transcript"
  mount ::DiscourseChatIntegration::Provider::HookEngine, at: "/chat-integration/"

  # For backwards compatibility with Slack plugin
  post "/slack/command" =>
         "discourse_chat_integration/provider/slack_provider/slack_command#command"
end
