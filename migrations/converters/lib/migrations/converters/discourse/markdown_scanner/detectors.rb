# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # Construct detectors, tried in priority order by the {Scanner} at each
        # trigger character. Each returns a {Match} or nil.
        module Detectors
          # Result of a successful detection. A nil `node` consumes the span without
          # producing anything: the scanner passes it through verbatim and resumes
          # after it, which is how a detector says "this is not a place to detect in"
          # (see {LinkSpan}).
          Match = Data.define(:start_pos, :end_pos, :node)
        end
      end
    end
  end
end
