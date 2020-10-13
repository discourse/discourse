# frozen_string_literal: true

require "ipaddr"

module Onebox
  module Engine
    class AllowlistedGenericOnebox

      # overwrite the allowlist
      def self.===(other)
        other.is_a?(URI) ? (IPAddr.new(other.hostname) rescue nil).nil? : true
      end

      # ensure we're the last engine to be used
      def self.priority
        Float::INFINITY
      end

    end
  end
end
