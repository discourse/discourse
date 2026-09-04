# frozen_string_literal: true

module Onebox
  class DomainChecker
    class << self
      def is_blocked?(hostname)
        normalized_hostname = hostname.to_s.downcase

        SiteSetting
          .blocked_onebox_domains
          &.split("|")
          &.any? do |blocked|
            normalized_blocked = blocked.downcase
            normalized_hostname == normalized_blocked ||
              normalized_hostname.end_with?(".#{normalized_blocked}")
          end
      end
    end
  end
end
