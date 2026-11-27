# frozen_string_literal: true

class AgentSetupController < ApplicationController
  GUIDE_PATH = Rails.root.join("lib/discourse_mcp/guides/agent_setup.md")
  # Clients name tools `mcp__<server>__<tool>`, and model APIs reject tool
  # names over 64 characters, so the name leaves room for the longest tool.
  MAX_SERVER_NAME_LENGTH = 16

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
        .gsub("{{server_name}}", server_name)

    render plain: markdown, content_type: "text/markdown; charset=utf-8"
  end

  private

  # A short name for the server in the agent's list, so it can tell this site
  # from others. It's only ASCII letters, digits and hyphens, so the title
  # can't put instructions into the guide.
  def server_name
    words = Slug.for(SiteSetting.title, "discourse", method: :ascii).split("-")
    name = words.first.first(MAX_SERVER_NAME_LENGTH)
    words
      .drop(1)
      .each do |word|
        break if name.length + word.length >= MAX_SERVER_NAME_LENGTH
        name = "#{name}-#{word}"
      end
    name
  end

  def ensure_mcp_enabled
    raise Discourse::NotFound if !SiteSetting.mcp_server_enabled
  end
end
