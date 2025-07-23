# frozen_string_literal: true

require "rails_helper"

describe DiscourseAi::Tokenizer::BertTokenizer do
  describe "#size" do
    describe "returns a token count" do
      it "for a single word" do
        expect(described_class.size("hello")).to eq(3)
      end

      it "for a sentence" do
        expect(described_class.size("hello world")).to eq(4)
      end

      it "for a sentence with punctuation" do
        expect(described_class.size("hello, world!")).to eq(6)
      end

      it "for a sentence with punctuation and capitalization" do
        expect(described_class.size("Hello, World!")).to eq(6)
      end

      it "for a sentence with punctuation and capitalization and numbers" do
        expect(described_class.size("Hello, World! 123")).to eq(7)
      end
    end
  end

  describe "#tokenizer" do
    it "returns a tokenizer" do
      expect(described_class.tokenizer).to be_a(Tokenizers::Tokenizer)
    end

    it "returns the same tokenizer" do
      expect(described_class.tokenizer).to eq(described_class.tokenizer)
    end
  end

  describe "#truncate" do
    it "truncates a sentence" do
      sentence = "foo bar baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 3)).to eq("foo bar")
    end
  end
end

describe DiscourseAi::Tokenizer::AnthropicTokenizer do
  describe "#size" do
    describe "returns a token count" do
      it "for a sentence with punctuation and capitalization and numbers" do
        expect(described_class.size("Hello, World! 123")).to eq(5)
      end
    end
  end

  describe "#truncate" do
    it "truncates a sentence" do
      sentence = "foo bar baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 3)).to eq("foo bar baz")
    end
  end
end

describe DiscourseAi::Tokenizer::OpenAiTokenizer do
  describe "#size" do
    describe "returns a token count" do
      it "for a sentence with punctuation and capitalization and numbers" do
        expect(described_class.size("Hello, World! 123")).to eq(6)
      end
    end
  end

  describe "#truncate" do
    it "truncates a sentence" do
      sentence = "foo bar baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 3)).to eq("foo bar baz")
    end

    it "truncates a sentence successfully at a multibyte unicode character" do
      sentence = "foo bar 👨🏿‍👩🏿‍👧🏿‍👧🏿 baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 7)).to eq("foo bar 👨🏿")
    end

    it "truncates unicode characters properly when they use more than one token per char" do
      sentence = "我喜欢吃比萨"
      original_size = described_class.size(sentence)
      expect(described_class.size(described_class.truncate(sentence, original_size - 1))).to be <
        original_size
    end
  end

  describe "#below_limit?" do
    it "returns true when the tokens can be expanded" do
      expect(described_class.below_limit?("foo bar baz qux", 6)).to eq(true)
    end

    it "returns false when the tokens cannot be expanded" do
      expect(described_class.below_limit?("foo bar baz qux", 3)).to eq(false)
    end

    it "returns false when the tokens cannot be expanded due to multibyte unicode characters" do
      expect(described_class.below_limit?("foo bar 👨🏿 baz qux", 6)).to eq(false)
    end

    it "handles unicode characters properly when they use more than one token per char" do
      expect(described_class.below_limit?("我喜欢吃比萨萨", 10)).to eq(false)
    end
  end
end

describe DiscourseAi::Tokenizer::OpenAiGpt4oTokenizer do
  describe "#size" do
    describe "returns a token count" do
      it "for a sentence with punctuation and capitalization and numbers" do
        expect(described_class.size("Hello, World! 123")).to eq(6)
      end
    end
  end
end

describe DiscourseAi::Tokenizer::AllMpnetBaseV2Tokenizer do
  describe "#size" do
    describe "returns a token count" do
      it "for a sentence with punctuation and capitalization and numbers" do
        expect(described_class.size("Hello, World! 123")).to eq(7)
      end
    end
  end

  describe "#truncate" do
    it "truncates a sentence" do
      sentence = "foo bar baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 3)).to eq("foo bar")
    end
  end
end

describe DiscourseAi::Tokenizer::MultilingualE5LargeTokenizer do
  describe "#size" do
    describe "returns a token count" do
      it "for a sentence with punctuation and capitalization and numbers" do
        expect(described_class.size("Hello, World! 123")).to eq(7)
      end
    end
  end

  describe "#truncate" do
    it "truncates a sentence" do
      sentence = "foo bar baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 3)).to eq("foo")
    end
  end
end

describe DiscourseAi::Tokenizer::BgeLargeEnTokenizer do
  describe "#size" do
    describe "returns a token count" do
      it "for a sentence with punctuation and capitalization and numbers" do
        expect(described_class.size("Hello, World! 123")).to eq(7)
      end
    end
  end

  describe "#truncate" do
    it "truncates a sentence" do
      sentence = "foo bar baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 3)).to eq("foo bar")
    end
  end
end

describe DiscourseAi::Tokenizer::BgeM3Tokenizer do
  describe "#size" do
    describe "returns a token count" do
      it "for a sentence with punctuation and capitalization and numbers" do
        expect(described_class.size("Hello, World! 123")).to eq(7)
      end
    end
  end

  describe "#truncate" do
    it "truncates a sentence" do
      sentence = "foo bar baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 3)).to eq("foo")
    end

    it "truncates a sentence successfully at a multibyte unicode character" do
      sentence = "foo bar 👨🏿‍👩🏿‍👧🏿‍👧🏿 baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 7)).to eq("foo bar 👨🏿")
    end

    it "truncates unicode characters properly when they use more than one token per char" do
      sentence = "我喜欢吃比萨"
      original_size = described_class.size(sentence)
      expect(described_class.size(described_class.truncate(sentence, original_size - 2))).to be <
        original_size
    end
  end
end

describe DiscourseAi::Tokenizer::Llama3Tokenizer do
  describe "#size" do
    describe "returns a token count" do
      it "for a sentence with punctuation and capitalization and numbers" do
        expect(described_class.size("Hello, World! 123")).to eq(7)
      end
    end
  end

  describe "#truncate" do
    it "truncates a sentence" do
      sentence = "foo bar baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 3)).to eq("foo bar")
    end

    # Llama3 fails here
    # it "truncates a sentence successfully at a multibyte unicode character" do
    #   sentence = "foo bar 👨🏿‍👩🏿‍👧🏿‍👧🏿 baz qux quux corge grault garply waldo fred plugh xyzzy thud"
    #   expect(described_class.truncate(sentence, 8)).to eq("foo bar 👨🏿")
    # end

    it "truncates unicode characters properly when they use more than one token per char" do
      sentence = "我喜欢吃比萨"
      original_size = described_class.size(sentence)
      expect(described_class.size(described_class.truncate(sentence, original_size - 2))).to be <
        original_size
    end
  end
end

describe DiscourseAi::Tokenizer::GeminiTokenizer do
  describe "#size" do
    describe "returns a token count" do
      it "for a sentence with punctuation and capitalization and numbers" do
        expect(described_class.size("Hello, World! 123")).to eq(9)
      end
    end
  end

  describe "#truncate" do
    it "truncates a sentence" do
      sentence = "foo bar baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 3)).to eq("foo bar")
    end

    it "truncates a sentence successfully at a multibyte unicode character" do
      sentence = "foo bar 👨🏿‍👩🏿‍👧🏿‍👧🏿 baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 8)).to eq("foo bar 👨🏿‍👩")
    end

    it "truncates unicode characters properly when they use more than one token per char" do
      sentence = "我喜欢吃比萨"
      original_size = described_class.size(sentence)
      expect(described_class.size(described_class.truncate(sentence, original_size - 2))).to be <
        original_size
    end
  end
end
