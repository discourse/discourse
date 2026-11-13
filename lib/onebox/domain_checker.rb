# frozen_string_literal: true

module Onebox
  class DomainChecker
    def self.is_blocked?(hostname)
      SiteSetting
        .blocked_onebox_domains
        &.split("|")
        &.any? { |blocked| HostnameNormalizer.within?(hostname, blocked) }
    end
  end
end
