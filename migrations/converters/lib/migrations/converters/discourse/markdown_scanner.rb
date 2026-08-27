# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      # Extraction of specific constructs (uploads, internal links, quote
      # references, mentions, hashtags, custom emoji) from Discourse Markdown,
      # leaving everything else untouched — including anything inside code,
      # whether fenced, indented, inline, a `[code]` block or a `<pre>` block.
      #
      # The division of labor: the discourse-markdown-it engine decides what
      # the markdown means — what is code, what is a live mention or link.
      # The {EngineScanner}'s certification and trial passes prove which raw
      # bytes produced each engine token. The {Detectors} do not parse
      # markdown context; they locate candidate byte spans, parse the
      # migration-specific syntax (quote headers, upload ids, internal
      # routes), and build the reference objects the importer resolves. The
      # {TierGate} skips bodies with nothing extractable before any of this
      # runs.
      #
      # The contract throughout: extraction can refuse a construct it cannot
      # prove, but it cannot corrupt one. Anything unproven stays unchanged,
      # and the body is counted with its cause on
      # `RawExtractor#engine_refusals` — the conversion's must-resolve list.
      module MarkdownScanner
      end
    end
  end
end
