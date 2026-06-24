# frozen_string_literal: true

require "securerandom"

module Migrations
  # Builds and recognises the tokens that stand in for embeds we can't finish while
  # converting a post (uploads, polls, events, quotes, links, mentions). Such an
  # embed needs the `original_id -> discourse_id` maps, which only exist at import
  # time. So the converter writes a token into `post.raw` and stores the same token
  # on a linkage row. The importer later swaps the token for real Markdown (see
  # `Migrations::Importer::PlaceholderResolver`).
  #
  # The token in `raw` and the token on the row must be exactly equal. That is what
  # lets the importer swap them with a plain `gsub`.
  #
  # A token looks like `<U+E000><nonce>.<kind>.<sequence><U+E000>`:
  #
  #   * U+E000 is a Private Use Area character. It never appears in real post
  #     content, so a token can't clash with it.
  #   * The nonce is random and set once per run, so a token can't be forged even if
  #     some source content did contain U+E000.
  #
  # `kind` and `sequence` only make a token easier to read while debugging.
  class Placeholder
    # The Private Use Area character that brackets every token.
    DELIMITER = "\u{E000}"

    # Matches a whole token, no matter which run created it.
    PATTERN = /#{DELIMITER}[^#{DELIMITER}]+#{DELIMITER}/

    # @param nonce [String] only override in tests, to get repeatable tokens.
    def initialize(nonce: SecureRandom.alphanumeric(16))
      @nonce = nonce
      @sequence = 0
    end

    # Returns the next token for an embed `kind`. Each call returns a new token.
    #
    # @param kind [Symbol, String]
    def mint(kind)
      @sequence += 1
      "#{DELIMITER}#{@nonce}.#{kind}.#{@sequence}#{DELIMITER}"
    end

    # @return [Array<String>] every token in `text`, in order.
    def self.scan(text)
      text.to_s.scan(PATTERN)
    end

    # @return [Boolean] whether `text` still contains a token.
    def self.include?(text)
      PATTERN.match?(text.to_s)
    end

    # Reads the `kind` out of a token (e.g. `"quote"`), or `nil` if `text` is not a
    # token. Returned as a plain string, never a symbol: it's only used to label
    # reports, and a stray U+E000 in source content could put anything here.
    #
    # @return [String, nil]
    def self.kind(text)
      inner = text.to_s[/\A#{DELIMITER}([^#{DELIMITER}]+)#{DELIMITER}\z/, 1]
      inner&.split(".")&.fetch(1, nil)
    end
  end
end
