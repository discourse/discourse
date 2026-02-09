# frozen_string_literal: true

module Discourse
  # work around reloader
  unless defined?(::Discourse::VERSION)
    module VERSION #:nodoc:
      # Use the `version_bump:*` rake tasks to update this value
      STRING = "2026.2.0-latest"

      PARTS = STRING.split(".")
      private_constant :PARTS

      MAJOR = PARTS[0].to_i
      MINOR = PARTS[1].to_i
      TINY = PARTS[2].to_i
      PRE = nil
      DEV = PARTS[2]&.split("-", 2)&.[](1)
    end
  end
end
