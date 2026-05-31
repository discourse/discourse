# frozen_string_literal: true

require "samovar"

module Migrations
  module CLI
    # Base class for all `disco` commands. Commands that need a booted Rails
    # environment declare `requires_rails!`; the binary boots Rails only after
    # such a command has been selected, keeping help and Rails-free commands
    # fast.
    class Command < Samovar::Command
      def self.requires_rails!
        @requires_rails = true
      end

      def self.requires_rails?
        return true if @requires_rails == true
        superclass.respond_to?(:requires_rails?) && superclass.requires_rails?
      end
    end
  end
end
