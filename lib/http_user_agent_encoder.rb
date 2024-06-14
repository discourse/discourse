# frozen_string_literal: true

module HttpUserAgentEncoder
  def self.ensure_utf8(user_agent)
    return "" unless user_agent

    if user_agent.encoding != Encoding::UTF_8
      user_agent = user_agent.encode!("utf-8", invalid: :replace, undef: :replace).scrub!
    end

    user_agent || ""
  end
end
