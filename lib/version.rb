module Discourse
  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 8
    TINY  = 3
    PRE   = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end