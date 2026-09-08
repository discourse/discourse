# frozen_string_literal: true

module DiscourseLograge
  class << self
    def enabled?
      ENV["ENABLE_LOGSTASH_LOGGER"] == "1"
    end

    def custom_payload(ip:, username:, **extras)
      { ip: ip, username: username, **extras.compact }
    end
  end
end
