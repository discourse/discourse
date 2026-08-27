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
      # anchors and parses certified occurrences with them.
      #
      # The contract throughout is fail-closed: extraction can refuse a
      # construct it cannot prove, but it cannot corrupt one. Anything
      # unproven stays verbatim, and the body is counted with its cause on
      # `RawExtractor#engine_refusals` — the conversion's must-resolve list.
      # Each class's docs carry the specific gap it accepts and why.
      module MarkdownScanner
      end
    end
  end
end
