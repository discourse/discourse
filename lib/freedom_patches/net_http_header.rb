# frozen_string_literal: true

module NetHTTPHeaderPatch
  def initialize_http_header(initheader)
    # If no user-agent is set, set it to the default
    initheader ||= {}
    user_agent_key =
      initheader.keys.find { |key| key.to_s.downcase == "user-agent" } || "User-Agent".to_sym
    initheader[user_agent_key] ||= Discourse.user_agent

    super initheader
  end
end

Net::HTTPHeader.prepend(NetHTTPHeaderPatch)
