# frozen_string_literal: true

module Discourse
  VERSION_REGEXP = /\A\d+\.\d+\.\d+(\.beta\d+)?\z/ unless defined? ::Discourse::VERSION_REGEXP

  # work around reloader
  unless defined? ::Discourse::VERSION
    module VERSION #:nodoc:
      MAJOR = 2
      MINOR = 6
      TINY  = 0
      PRE   = 'beta1'

      STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
    end
  end

  def self.has_needed_version?(current, needed)
    Gem::Version.new(current) >= Gem::Version.new(needed)
  end
end
