module Discourse
  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 8
    TINY  = 1
    PRE   = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end