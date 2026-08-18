# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      # Single-pass scanner for Discourse Markdown that extracts specific constructs
      # (uploads, internal links, quote references, mentions, hashtags, custom
      # emoji) while leaving everything else untouched — including anything inside
      # code, whether fenced, indented, inline, a `[code]` block or a `<pre>` block.
      #
      # {Scanner} walks the input; on a successful match it asks the supplied block
      # for the replacement text (a placeholder token) and skips past the matched
      # span. The pieces live in `markdown_scanner/`: {Scanner}, the {BlockTracker}
      # (with its {LineClassifier}) that decides what is code, and the {Detectors}.
      # The knowingly accepted divergences from core are listed in
      # `markdown_scanner/LIMITATIONS.md`.
      module MarkdownScanner
      end
    end
  end
end
