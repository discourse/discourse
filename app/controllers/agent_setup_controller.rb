# frozen_string_literal: true

class AgentSetupController < ApplicationController
  GUIDE_PATH = Rails.root.join("lib/discourse_mcp/guides/agent_setup.md")

  skip_before_action :check_xhr,
                     :preload_json,
                     :handle_theme,
                     :redirect_to_login_if_required,
                     :redirect_to_profile_if_required
  before_action :ensure_mcp_enabled

  def show
    markdown =
      File
        .read(GUIDE_PATH)
        .gsub("{{base_url}}", Discourse.base_url)
        .gsub("{{mcp_url}}", DiscourseMcp.resource_url)

    render plain: markdown, content_type: "text/markdown; charset=utf-8"
  end

  private

  def ensure_mcp_enabled
    raise Discourse::NotFound if !SiteSetting.mcp_server_enabled
  end
end
