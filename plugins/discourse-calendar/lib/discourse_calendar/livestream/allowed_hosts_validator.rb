# frozen_string_literal: true

module DiscourseCalendar
  module Livestream
    # Replaces the default `host_list` validator, which only rejects wildcards.
    class AllowedHostsValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        @invalid =
          val
            .to_s
            .split("|")
            .map(&:strip)
            .reject(&:blank?)
            .reject { |entry| entry.match?(AllowedHosts::HOST_FORMAT) }

        @invalid.empty?
      end

      def error_message
        I18n.t("site_settings.livestream_allowed_hosts_invalid", hosts: @invalid.join(", "))
      end
    end
  end
end
