module Discourse
  # work around reloader
  unless defined? ::Discourse::VERSION
    module VERSION #:nodoc:
      MAJOR = 1
      MINOR = 1
      TINY  = 1
      PRE   = nil

      STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
    end
  end
end
