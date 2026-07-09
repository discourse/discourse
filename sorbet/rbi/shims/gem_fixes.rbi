# typed: true

# Gems that ship their own RBIs (prism, pdf-reader) reference constants that
# don't resolve without the rest of their dependency graph in the payload.
# Declare the missing names so `srb tc` stays green.

module Prism
  module LexCompat
    class Result < Prism::Result
    end
  end
end

module TTFunk
  class File
  end
end
