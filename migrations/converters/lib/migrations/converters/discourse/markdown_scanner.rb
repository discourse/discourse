# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      # Single-pass scanner for Discourse Markdown that extracts specific constructs
      # (uploads, quote attributions, mentions) while leaving everything else — and,
      # crucially, anything inside fenced/indented/inline **code** — untouched.
      #
      # {Scanner} walks the input character by character; on a successful match it
      # asks the supplied block for the replacement text (a placeholder token) and
      # skips past the matched span. The pieces live in `markdown_scanner/`:
      # {Scanner}, {CodeBlockTracker} and the {Detectors}.
      module MarkdownScanner
      end
    end
  end
end
