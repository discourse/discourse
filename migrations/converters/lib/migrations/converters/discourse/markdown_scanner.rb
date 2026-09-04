# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      # Extraction of specific constructs (uploads, internal links, quote
      # references, mentions, hashtags, custom emoji) from Discourse Markdown,
      # leaving everything else untouched — including anything inside code,
      # whether fenced, indented, inline, a `[code]` block or a `<pre>` block.
      #
      # The division of labor: the discourse-markdown-it engine decides what the
      # markdown means — what is code, what is a live mention or link. The
      # {EngineScanner} recovers which raw bytes produced each engine token. The
      # {Constructs} do not parse markdown context; they hold the source's name
      # sets, parse the migration-specific syntax (quote headers, upload ids,
      # internal routes) and build the reference objects the importer resolves.
      # The {TierGate} skips bodies with nothing extractable before any of this
      # runs.
      #
      # ## Why counting is sound
      #
      # The engine's inline tokens have no source offsets, so positions are
      # recovered by counting raw occurrences of a token's value. Counting is
      # dumb on purpose — the bytes alone, with no boundary rule and no name
      # grammar. Every live construct spells its value in the raw and one raw
      # occurrence yields at most one token, so the raw count is never below the
      # token count, and equality then forces every occurrence to be live. Any
      # rule that could reject a raw occurrence — a boundary condition, a name
      # grammar, "this looks like a longer URL" — can only lower the count, and
      # the freed token then gets matched to a look-alike inside a code span
      # instead, which corrupts the body.
      #
      # Two conditions are allowed anyway, because they protect the premise that
      # the bytes are there at all:
      #
      #   * a body with a construct-capable character entity refuses, since
      #     `&commat;bob` yields a token whose bytes appear nowhere;
      #   * names are counted folded, at least as coarsely as the engine folds
      #     them ({FoldedText}). Both sides fold through
      #     `NameNormalizer.normalize`, which also merges the two lowercase
      #     sigmas: JavaScript's `toLowerCase` and Ruby's `downcase` disagree on
      #     a word-final `Σ`, and a fold coarser than the engine's is what the
      #     argument above needs.
      #
      # Two byte-level exclusions drop URL hits anyway, because no live link
      # can spell them:
      #
      #   * a hit of a schemeless reading right after `//` is the tail of some
      #     scheme-ful spelling, since linkify starts no bare-domain link
      #     there;
      #   * a hit that lies strictly inside a hit of another tracked value is
      #     part of that longer value's byte run, so a live link there spells
      #     the longer value — and where the run is shielded, both hits are.
      #     A value the engine counted inside a link label is exempt, because
      #     there the shorter value really does occur inside the longer one's
      #     link.
      #
      # Counts that cannot be matched escalate to
      # {EngineScanner::SubstitutionPass}, which asks the engine about one
      # occurrence at a time.
      #
      # ## Refuse, never corrupt
      #
      # Extraction can refuse a construct it cannot confirm, but it cannot
      # corrupt one. Anything unconfirmed stays unchanged, and the body is
      # counted with its cause on `RawExtractor#engine_refusals` — the
      # conversion's must-resolve list. A confirmed occurrence is recorded from
      # the author's own raw bytes, never from the engine's normalized spelling.
      #
      # Accepted gaps:
      #
      #   * A raw URL spelling that none of the readings reconstructs —
      #     percent-encoding with lowercase hex digits, say, which the engine's
      #     href normalizes to uppercase — is not counted, so the body refuses
      #     instead of being rewritten.
      #   * A name that also occurs inside a longer one — `@bob` in `@bobby` —
      #     counts one occurrence too many and escalates. A body with hundreds
      #     of such pairs runs out of substitution budget and keeps its tail
      #     verbatim.
      #   * A custom emoji name outside {Constructs::Emoji}'s presence shape
      #     never reaches the engine tier at all: the gate cannot see it, so
      #     nothing is extracted and nothing is reported.
      #   * A mail gateway's link-scanner wrapper around an upload URL
      #     (`…/__https:/host/secure-uploads/…__;!!…$`) is the scanner's link,
      #     not the site's: the upload shape inside it is what the value tracks,
      #     so a wrapper in prose keeps the file and loses the redirect, and one
      #     in a destination refuses on its trailing marker.
      module MarkdownScanner
      end
    end
  end
end
