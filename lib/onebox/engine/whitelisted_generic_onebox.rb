module Onebox
  module Engine
    class WhitelistedGenericOnebox

      # overwrite the whitelist
      def self.===(other)
        true
      end

      # ensure we're the last engine to be used
      def self.priority
        Float::INFINITY
      end

    end
  end
end
