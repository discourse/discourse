# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # One class per construct kind, tried in priority order at each
        # trigger character. Each returns a {Match} or nil.
        module Constructs
          # Result of a successful detection: the byte span the construct
          # covers and the AST node describing it.
          Match = Data.define(:start_pos, :end_pos, :node)
        end
      end
    end
  end
end
