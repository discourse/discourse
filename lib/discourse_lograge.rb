# frozen_string_literal: true

module DiscourseLograge
  def self.enabled?
    ENV["ENABLE_LOGSTASH_LOGGER"] == "1"
  end

  def self.custom_payload(ip:, username:, **extras)
    { ip: ip, username: username, **extras.compact }
  end
end
