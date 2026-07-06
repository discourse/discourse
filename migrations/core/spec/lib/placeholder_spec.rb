# frozen_string_literal: true

RSpec.describe Migrations::Placeholder do
  subject(:placeholder) { described_class.new(nonce: "testnonce") }

  describe "#mint" do
    it "wraps every token in the Private Use Area delimiter" do
      token = placeholder.mint(:quote)

      expect(token).to start_with(described_class::DELIMITER)
      expect(token).to end_with(described_class::DELIMITER)
    end

    it "embeds the nonce and kind for readability" do
      expect(placeholder.mint(:upload)).to include("testnonce", "upload")
    end

    it "lays out the nonce, kind and a 1-based sequence between delimiters" do
      d = described_class::DELIMITER

      expect(placeholder.mint(:quote)).to eq("#{d}testnonce.quote.1#{d}")
      expect(placeholder.mint(:link)).to eq("#{d}testnonce.link.2#{d}")
    end

    it "mints a unique token on every call" do
      tokens = Array.new(5) { placeholder.mint(:link) }

      expect(tokens.uniq.size).to eq(5)
    end

    it "produces different tokens across runs (different nonces)" do
      other = described_class.new

      expect(placeholder.mint(:quote)).not_to eq(other.mint(:quote))
    end

    it "defaults to a random nonce, so two fresh instances never collide" do
      # Guards the default `nonce:` argument: without a random nonce both
      # instances would mint the identical `<delim>.quote.1<delim>`.
      expect(described_class.new.mint(:quote)).not_to eq(described_class.new.mint(:quote))
    end

    it "defaults to a 16-character alphanumeric nonce" do
      d = described_class::DELIMITER
      nonce = described_class.new.mint(:quote).delete(d).split(".").first

      expect(nonce).to match(/\A[a-zA-Z0-9]{16}\z/)
    end

    it "does not produce a token that could appear in ordinary user content" do
      token = placeholder.mint(:mention)
      sentence = "a normal sentence with @mentions and [links](http://x)"

      # The delimiter is a private-use code point, so it cannot occur in real text.
      expect(sentence).not_to include(described_class::DELIMITER)
      expect(token).to include(described_class::DELIMITER)
    end
  end

  describe ".scan" do
    it "finds every token in a raw body, in order" do
      first = placeholder.mint(:quote)
      second = placeholder.mint(:link)
      raw = "before #{first} middle #{second} after"

      expect(described_class.scan(raw)).to eq([first, second])
    end

    it "returns an empty array when there are no tokens" do
      expect(described_class.scan("no tokens here")).to be_empty
    end

    it "tolerates nil" do
      expect(described_class.scan(nil)).to be_empty
    end
  end

  describe ".include?" do
    it "is true when a token is present" do
      raw = "x #{placeholder.mint(:event)} y"

      expect(described_class).to be_include(raw)
    end

    it "is false for plain text" do
      expect(described_class).not_to be_include("just text")
    end

    it "is false for nil" do
      expect(described_class).not_to be_include(nil)
    end
  end

  describe ".kind" do
    it "parses the embed kind out of a token" do
      expect(described_class.kind(placeholder.mint(:quote))).to eq("quote")
      expect(described_class.kind(placeholder.mint(:upload))).to eq("upload")
    end

    it "returns nil for text that isn't a token" do
      expect(described_class.kind("just text")).to be_nil
      expect(described_class.kind(nil)).to be_nil
    end

    it "only reads the kind out of a fully delimited token" do
      # Dotted text without the delimiters must not be parsed as a token, even
      # though it splits into the same shape as a real one.
      expect(described_class.kind("nonce.quote.1")).to be_nil
    end

    it "is nil when a delimited token carries no kind segment" do
      d = described_class::DELIMITER

      # A stray delimiter pair in source content need not hold `nonce.kind.seq`.
      expect(described_class.kind("#{d}whatever#{d}")).to be_nil
    end

    it "returns the kind without the surrounding delimiters" do
      d = described_class::DELIMITER

      # Reads capture group 1 (inner text), not the whole match, so no stray
      # delimiter clings to the last segment.
      expect(described_class.kind("#{d}nonce.quote#{d}")).to eq("quote")
    end
  end
end
