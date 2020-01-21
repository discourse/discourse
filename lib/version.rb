# frozen_string_literal: true

module Discourse
  VERSION_REGEXP = /\A\d+\.\d+\.\d+(\.beta\d+)?\z/ unless defined? ::Discourse::VERSION_REGEXP

  # work around reloader
  unless defined? ::Discourse::VERSION
    module VERSION #:nodoc:
      MAJOR = 2
      MINOR = 4
      TINY  = 0
      PRE   = 'beta10'

      STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
    end
  end

  def self.has_needed_version?(current, needed)
    current_split = current.split('.')
    needed_split = needed.split('.')

    (0..[current_split.size, needed_split.size].max).each do |idx|
      current_str = current_split[idx] || ''

      c0 = (needed_split[idx] || '').sub('beta', '').to_i
      c1 = (current_str || '').sub('beta', '').to_i

      # beta is less than stable
      return false if current_str.include?('beta') && (c0 == 0) && (c1 > 0)

      return true if c1 > c0
      return false if c0 > c1
    end

    true
  end
end
