# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      # Extraction of specific constructs (uploads, internal links, quote
      # references, mentions, hashtags, custom emoji) from Discourse Markdown,
      # leaving everything else untouched — including anything inside code,
      # whether fenced, indented, inline, a `[code]` block or a `<pre>` block.
      #
      # The pieces live in `markdown_scanner/`: the {TierGate} skips the bodies
      # with nothing extractable, and the {EngineScanner} handles the rest by
      # parsing with the real discourse-markdown-it engine and locating every
      # reported construct through count certification (escalating to
      # per-occurrence trial substitution). The {Detectors} carry the construct
      # grammars — the gate probes candidacy with them, the engine scanner
      # anchors and parses certified occurrences with them. What extraction
      # knowingly leaves undone is listed in `markdown_scanner/LIMITATIONS.md`.
      module MarkdownScanner
      end
    end
  end
end
