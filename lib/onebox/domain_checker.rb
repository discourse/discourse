# frozen_string_literal: true

module Onebox
  class DomainChecker
    def self.is_blocked?(hostname)
      normalized_hostname = normalize(hostname)

      SiteSetting
        .blocked_onebox_domains
        &.split("|")
        &.any? do |blocked|
          normalized_blocked = normalize(blocked)
          normalized_hostname == normalized_blocked ||
            normalized_hostname.end_with?(".#{normalized_blocked}")
        end
    end

    def self.normalize(hostname)
      hostname.to_s.downcase.sub(/\.+\z/, "")
    end
  end
end
