# frozen_string_literal: true

module Imap
  module Providers
    class Detector
      def self.init_with_detected_provider(config)
        if config[:server] == "imap.gmail.com"
          return Imap::Providers::Gmail.new(config[:server], config)
        end
        Imap::Providers::Generic.new(config[:server], config)
      end
    end
  end
end
