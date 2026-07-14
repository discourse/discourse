# frozen_string_literal: true

module Migrations
  module Tooling
    module Coverage
      # Raised when a converter source cannot be analysed with confidence: a
      # parse failure, or a `.create` call site that passes a `**` splat or a
      # non-literal keyword. Such call sites can't be verified statically, so the
      # analyser fails loudly rather than silently under-reporting coverage.
      class AnalysisError < StandardError
        include Migrations::CLI::PresentableError
      end
    end
  end
end
