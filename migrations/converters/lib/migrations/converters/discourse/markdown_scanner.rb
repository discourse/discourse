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
      # The {EngineScanner}'s count-matching and substitution passes confirm
      # which raw bytes produced each engine token; counting reads the bytes
      # only, with no grammar of its own, because a rule that can reject a raw
      # occurrence core does cook is what lets a look-alike take a live
      # token's place. The {Constructs} do not parse markdown context; they
      # hold the source's name sets, parse the migration-specific syntax
      # (quote headers, upload ids, internal routes) and build the reference
      # objects the importer resolves. The {TierGate} skips bodies with
      # nothing extractable before any of this runs.
      #
      # The contract throughout: extraction can refuse a construct it cannot
      # confirm, but it cannot corrupt one. Anything unconfirmed stays
      # unchanged, and the body is counted with its cause on
      # `RawExtractor#engine_refusals` — the conversion's must-resolve list.
      #
      # Accepted gaps:
      #
      #   * A raw URL spelling no reading reconstructs — percent-encoding with
      #     lowercase hex digits, say, which the engine's href normalizes to
      #     uppercase — is not counted, so the body refuses instead of being
      #     rewritten.
      #   * A tracked value that also occurs inside a longer one — `/t/x/5` in
      #     `/t/x/55`, `@bob` in `@bobby` — counts one occurrence too many and
      #     escalates. Substitution then confirms the live occurrences one by
      #     one, at one engine parse each, and a body with hundreds of such
      #     pairs runs out of substitution budget and keeps its tail verbatim.
      #   * A custom emoji name outside {Constructs::Emoji}'s presence shape
      #     never reaches the engine tier at all: the gate cannot see it, so
      #     nothing is extracted and nothing is reported.
      #
      # The fold on both sides is `NameNormalizer.normalize`, which also merges
      # the two lowercase sigmas: JavaScript's `toLowerCase` and Ruby's
      # `downcase` disagree on a word-final `Σ`, and a fold that is not at least
      # as coarse as the engine's would break the counting argument above.
      module MarkdownScanner
      end
    end
  end
end
