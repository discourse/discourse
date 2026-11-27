# frozen_string_literal: true

module McpOauthAuthorizationsHelper
  # Says where approving sends the person. Apps on this device get their own
  # wording, and their port, since that's what tells one local app from another.
  def mcp_redirect_notice(redirect_uri)
    uri = URI.parse(redirect_uri)

    if McpOauthClient::LOCAL_REDIRECT_HOSTS.include?(uri.hostname.downcase)
      host = uri.port == uri.default_port ? uri.host : "#{uri.host}:#{uri.port}"
      t("mcp.oauth.redirect_local_html", host: tag.strong(host))
    else
      t("mcp.oauth.redirect_html", host: tag.strong(uri.host))
    end
  end
end
