# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      # Single-pass scanner for Discourse Markdown that extracts specific constructs
      # (uploads, quote attributions, mentions) while leaving everything else — and,
      # crucially, anything inside fenced/indented/inline **code** — untouched.
      #
      # This is vendored from Markbridge's `Processors::DiscourseMarkdown`
      # (`Scanner` + `CodeBlockTracker` + the upload/mention detectors), which was
      # removed in Markbridge 0.2.1 — the gem keeps only the format-agnostic AST and
      # renderer, so this Discourse-specific scanning lives here now. We still rely
      # on `Markbridge::AST::*` for the node types.
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
