# frozen_string_literal: true

require "securerandom"

module Migrations
  # Creates and finds the tokens that stand in for embeds we can't finish while we
  # convert a post (uploads, polls, events, quotes, links, mentions). Such an embed
  # needs the `original_id -> discourse_id` maps, which only exist at import time.
  # So the converter puts a token into `post.raw` and stores the same token on a
  # linkage row. The importer later swaps the token for real Markdown (see
  # `Migrations::Importer::PlaceholderResolver`).
  #
  # The token in `raw` and the token on the row must be exactly equal. That is what
  # lets the importer swap them with a plain `gsub`.
  #
  # A token looks like `<U+E000><nonce>.<kind>.<sequence><U+E000>`:
  #
  #   * U+E000 is a Private Use Area character. It never appears in real post
  #     content, so a token can't be confused with real text.
  #   * The nonce is random and set once per run, so a token can't be faked even if
  #     some source content does contain U+E000.
  #
  # `kind` and `sequence` only make a token easier to read while debugging.
  class Placeholder
    DELIMITER = "\u{E000}"

    # Matches one whole token, from any run.
    PATTERN = /#{DELIMITER}[^#{DELIMITER}]+#{DELIMITER}/

    # @param nonce [String] only override in tests, to get repeatable tokens.
    def initialize(nonce: SecureRandom.alphanumeric(16))
      @nonce = nonce
      @sequence = 0
    end

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

    # The `kind` of a token (e.g. `"quote"`), or `nil` if `text` is not a token. A
    # plain string, never a symbol: it only labels reports, and a stray U+E000 in
    # source content could put anything here.
    #
    # @return [String, nil]
    def self.kind(text)
      inner = text.to_s[/\A#{DELIMITER}([^#{DELIMITER}]+)#{DELIMITER}\z/, 1]
      inner&.split(".")&.fetch(1, nil)
    end
  end
end
