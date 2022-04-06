# frozen_string_literal: true

module Onebox
  class DomainChecker
    def self.is_blocked?(hostname)
      SiteSetting.blocked_onebox_domains&.split('|').any? do |blocked|
        hostname == blocked || hostname.end_with?(".#{blocked}")
      end
    end
  end
end
