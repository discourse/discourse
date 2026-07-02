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

    it "mints a unique token on every call" do
      tokens = Array.new(5) { placeholder.mint(:link) }

      expect(tokens.uniq.size).to eq(5)
    end

    it "produces different tokens across runs (different nonces)" do
      other = described_class.new

      expect(placeholder.mint(:quote)).not_to eq(other.mint(:quote))
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
  end
end
