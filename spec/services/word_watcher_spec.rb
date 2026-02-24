# frozen_string_literal: true

RSpec.describe WordWatcher do
  def matches(text, action = :require_approval)
    described_class.new(text).word_matches_for_action?(action)
  end

  def matches_all(text, action = :block)
    described_class.new(text).word_matches_for_action?(action, all_matches: true)
  end

  after { Discourse.redis.flushdb }

  describe ".words_for_action" do
    it "returns words with metadata including case sensitivity flag" do
      Fabricate(:watched_word, action: WatchedWord.actions[:censor])
      word1 = Fabricate(:watched_word, action: WatchedWord.actions[:block]).word
      word2 =
        Fabricate(:watched_word, action: WatchedWord.actions[:block], case_sensitive: true).word

      expect(described_class.words_for_action(:block)).to include(
        word1 => {
          case_sensitive: false,
          word: word1,
        },
        word2 => {
          case_sensitive: true,
          word: word2,
        },
      )
    end

    it "returns word with metadata including replacement if word has replacement" do
      word =
        Fabricate(
          :watched_word,
          action: WatchedWord.actions[:link],
          replacement: "http://test.localhost/",
        ).word

      expect(described_class.words_for_action(:link)).to include(
        word => {
          case_sensitive: false,
          replacement: "http://test.localhost/",
          word: word,
        },
      )
    end

    it "returns an empty hash when no words are present" do
      expect(described_class.words_for_action(:tag)).to eq({})
    end
  end

  describe ".compiled_regexps_for_action" do
    let!(:word1) { Fabricate(:watched_word, action: WatchedWord.actions[:block]).word }
    let!(:word2) { Fabricate(:watched_word, action: WatchedWord.actions[:block]).word }
    let!(:word3) do
      Fabricate(:watched_word, action: WatchedWord.actions[:block], case_sensitive: true).word
    end
    let!(:word4) do
      Fabricate(:watched_word, action: WatchedWord.actions[:block], case_sensitive: true).word
    end

    context "when watched_words_regular_expressions = true" do
      before { SiteSetting.watched_words_regular_expressions = true }

      it "matches words and respects case sensitivity" do
        regexps = described_class.compiled_regexps_for_action(:block)

        case_insensitive = regexps.find(&:casefold?)
        case_sensitive = regexps.find { |r| !r.casefold? }

        expect(case_insensitive).to match(word1)
        expect(case_insensitive).to match(word2)
        expect(case_insensitive).to match(word1.upcase)
        expect(case_sensitive).to match(word3)
        expect(case_sensitive).to match(word4)
        expect(case_sensitive).not_to match(word3.swapcase)
      end
    end

    context "when watched_words_regular_expressions = false" do
      it "groups words by case sensitivity and wraps them with word boundaries" do
        SiteSetting.watched_words_regular_expressions = false
        regexps = described_class.compiled_regexps_for_action(:block)

        case_sensitive = regexps.find { |r| !r.casefold? }
        case_insensitive = regexps.find(&:casefold?)

        expect(case_insensitive).to match(word1)
        expect(case_insensitive).to match(word2)
        expect(case_sensitive).to match(word3)
        expect(case_sensitive).to match(word4)

        expect(case_insensitive).not_to match("x#{word1}x")
        expect(case_sensitive).not_to match("x#{word3}x")
      end

      it "is empty for an action without watched words" do
        expect(described_class.compiled_regexps_for_action(:censor)).to be_empty
      end
    end

    context "when regular expression is invalid" do
      before do
        SiteSetting.watched_words_regular_expressions = true
        Fabricate(:watched_word, word: "Test[\S*", action: WatchedWord.actions[:block])
      end

      it "does not raise an exception by default" do
        expect { described_class.compiled_regexps_for_action(:block) }.not_to raise_error
        expect(described_class.compiled_regexps_for_action(:block)).to contain_exactly(
          /(#{word1})|(#{word2})/i,
          /(#{word3})|(#{word4})/,
        )
      end

      it "raises an exception with raise_errors set to true" do
        expect {
          described_class.compiled_regexps_for_action(:block, raise_errors: true)
        }.to raise_error(RegexpError)
      end
    end

    context "when there's a wildcard watched word" do
      before do
        SiteSetting.watched_words_regular_expressions = false
        WatchedWord.where(action: WatchedWord.actions[:block]).delete_all
        Fabricate(:watched_word, word: "*abc", action: WatchedWord.actions[:block])
      end

      it "works correctly when regular expressions are disabled" do
        regexps = described_class.compiled_regexps_for_action(:block)
        expect(regexps.first).to match("xyzabc")
        expect(regexps.first).to match(" abc")
        expect(regexps.first).to match("testabc")
        expect(regexps.first).not_to match("abcdef")
      end

      it "skips invalid watched words when regular expression are enabled" do
        SiteSetting.watched_words_regular_expressions = true
        expect(described_class.compiled_regexps_for_action(:block)).to be_empty
      end
    end

    context "when there's an invalid regex that causes compilation to fail" do
      before do
        SiteSetting.watched_words_regular_expressions = true
        WatchedWord.where(action: WatchedWord.actions[:block]).delete_all
        Fabricate(:watched_word, word: "test[[", action: WatchedWord.actions[:block])
        Fabricate(:watched_word, word: "bad", action: WatchedWord.actions[:block])
        Fabricate(:watched_word, word: "word", action: WatchedWord.actions[:block])
      end

      it "still matches valid words even with invalid regex present" do
        expect { described_class.compiled_regexps_for_action(:block) }.not_to raise_error
        expect(matches_all("This is a bad word")).to include("bad", "word")
      end

      it "does not break serialized_regexps_for_action" do
        expect { described_class.serialized_regexps_for_action(:block) }.not_to raise_error
        serialized = described_class.serialized_regexps_for_action(:block)
        expect(serialized).not_to be_empty
      end
    end
  end

  describe "#word_matches_for_action?" do
    it "is falsey when there are no watched words" do
      expect(matches("nothing to see here")).to be_falsey
    end

    context "with watched words" do
      fab!(:anise) do
        Fabricate(:watched_word, word: "anise", action: WatchedWord.actions[:require_approval])
      end

      it "is falsey without a match" do
        expect(matches("No liquorice for me, thanks...")).to be_falsey
      end

      it "returns matched word on match" do
        expect(matches("I like anise")[1]).to eq("anise")
      end

      it "finds at start of string" do
        expect(matches("#{anise.word} is garbage")[1]).to eq(anise.word)
      end

      it "finds at end of string" do
        expect(matches("who likes #{anise.word}")[1]).to eq(anise.word)
      end

      it "finds non-letters in place of letters" do
        Fabricate(:watched_word, word: "co(onut", action: WatchedWord.actions[:require_approval])
        expect(matches("This co(onut is delicious.")[1]).to eq("co(onut")
      end

      it "handles * for wildcards" do
        Fabricate(:watched_word, word: "a**le*", action: WatchedWord.actions[:require_approval])
        expect(matches("I acknowledge you.")[1]).to eq("acknowledge")
      end

      it "matches words at boundaries with punctuation" do
        Fabricate(:watched_word, word: "love", action: WatchedWord.actions[:require_approval])

        %w[Love, LOVE; love: love. :love. ,love].each do |token|
          text = "I #{token} things"
          word = token.gsub(/[^a-zA-Z]/, "")
          expect(matches(text)[1]).to eq(word), "expected '#{word}' to match in '#{text}'"
        end
      end

      it "matches CJK watched words within CJK text" do
        Fabricate(:watched_word, word: "测试", action: WatchedWord.actions[:require_approval])

        expect(matches("测试")[1]).to eq("测试")
        expect(matches("这是一个测试文本")[1]).to eq("测试")
        expect(matches("hello 测试 world")[1]).to eq("测试")
        expect(matches("API测试结果")[1]).to eq("测试")
      end

      it "matches Latin watched words adjacent to CJK text" do
        Fabricate(:watched_word, word: "Test", action: WatchedWord.actions[:require_approval])

        expect(matches("我的Test很好")[1]).to eq("Test")
        expect(matches("Testing")).to be_falsey
      end

      it "does not match across word boundaries" do
        Fabricate(:watched_word, word: "Test", action: WatchedWord.actions[:require_approval])

        expect(matches("Test")[1]).to eq("Test")
        expect(matches("Test 123")[1]).to eq("Test")
        expect(matches("123Test")).to be_falsey
        expect(matches("Test123")).to be_falsey

        Fabricate(:watched_word, word: "test", action: WatchedWord.actions[:require_approval])
        expect(matches("foo_test_bar")).to be_falsey
        expect(matches("_test")).to be_falsey
        expect(matches("test_")).to be_falsey
        expect(matches("foo-test-bar")[1]).to eq("test")
      end

      it "treats numbers as word characters at boundaries" do
        Fabricate(:watched_word, word: "123", action: WatchedWord.actions[:require_approval])

        expect(matches("hello 123 world")[1]).to eq("123")
        expect(matches("abc123")).to be_falsey
        expect(matches("123abc")).to be_falsey
      end

      context "when there are multiple matches" do
        context "with non regexp words" do
          it "lists all matching words" do
            %w[bananas hate hates].each do |word|
              Fabricate(:watched_word, word: word, action: WatchedWord.actions[:block])
            end

            expect(matches_all("I hate bananas")).to contain_exactly("hate", "bananas")
            expect(matches_all("She hates bananas too")).to contain_exactly("hates", "bananas")
          end
        end

        context "with regexp words" do
          before { SiteSetting.watched_words_regular_expressions = true }

          it "lists all matching patterns" do
            Fabricate(:watched_word, word: "(pine)?apples", action: WatchedWord.actions[:block])
            Fabricate(
              :watched_word,
              word: "((move|store)(d)?)|((watch|listen)(ed|ing)?)",
              action: WatchedWord.actions[:block],
            )

            expect(matches_all("pine pineapples apples")).to contain_exactly("pineapples", "apples")

            expect(
              matches_all("go watched watch ed ing move d moveed moved moving"),
            ).to contain_exactly(*%w[watched watch move moved])
          end
        end
      end

      context "when word is an emoji" do
        it "handles emoji" do
          Fabricate(:watched_word, word: ":joy:", action: WatchedWord.actions[:require_approval])
          expect(matches("Lots of emojis here :joy:")[1]).to eq(":joy:")
        end

        it "handles unicode emoji" do
          Fabricate(:watched_word, word: "🎃", action: WatchedWord.actions[:require_approval])
          expect(matches("Halloween party! 🎃")[1]).to eq("🎃")
        end

        it "handles emoji skin tone" do
          Fabricate(
            :watched_word,
            word: ":woman:t5:",
            action: WatchedWord.actions[:require_approval],
          )
          expect(matches("To Infinity and beyond! 🚀 :woman:t5:")[1]).to eq(":woman:t5:")
        end
      end

      context "when word is a regular expression" do
        before { SiteSetting.watched_words_regular_expressions = true }

        it "supports regular expressions on word boundaries" do
          Fabricate(:watched_word, word: /\btest\b/, action: WatchedWord.actions[:block])
          expect(matches("this is not a test.", :block)[0]).to eq("test")
        end

        it "supports regular expressions as a site setting" do
          Fabricate(
            :watched_word,
            word: /tro[uo]+t/,
            action: WatchedWord.actions[:require_approval],
          )

          expect(matches("Evil Trout is cool")[0]).to eq("Trout")
          expect(matches("Evil Troot is cool")[0]).to eq("Troot")
          expect(matches("trooooooooot")[0]).to eq("trooooooooot")
        end

        it "support uppercase" do
          Fabricate(:watched_word, word: /a\S+ce/, action: WatchedWord.actions[:require_approval])

          expect(matches("Amazing place")).to be_nil
          expect(matches("Amazing applesauce")[0]).to eq("applesauce")
          expect(matches("Amazing AppleSauce")[0]).to eq("AppleSauce")
        end
      end

      context "when case sensitive words are present" do
        before do
          Fabricate(
            :watched_word,
            word: "Discourse",
            action: WatchedWord.actions[:block],
            case_sensitive: true,
          )
        end

        context "when watched_words_regular_expressions = true" do
          it "respects case sensitivity flag in matching words" do
            SiteSetting.watched_words_regular_expressions = true
            Fabricate(:watched_word, word: "p(rivate|ublic)", action: WatchedWord.actions[:block])

            expect(
              matches_all("PUBLIC: Discourse is great for public discourse"),
            ).to contain_exactly("PUBLIC", "Discourse", "public")
          end
        end

        context "when watched_words_regular_expressions = false" do
          it "repects case sensitivity flag in matching" do
            SiteSetting.watched_words_regular_expressions = false
            Fabricate(:watched_word, word: "private", action: WatchedWord.actions[:block])

            expect(
              matches_all("PRIVATE: Discourse is also great private discourse"),
            ).to contain_exactly("PRIVATE", "Discourse", "private")
          end
        end
      end
    end
  end

  describe "#word_matches_across_all_actions" do
    it("returns an array of words") do
      Fabricate(:watched_word, action: WatchedWord.actions[:flag], word: "foo")
      Fabricate(:watched_word, action: WatchedWord.actions[:block], word: "bar")
      Fabricate(:watched_word, action: WatchedWord.actions[:silence], word: "baz")

      contentful_check = described_class.new("Going to match the baz, the foo, and the bar.")

      expect(contentful_check.word_matches_across_all_actions).to contain_exactly(
        "foo",
        "bar",
        "baz",
      )
    end
  end

  describe "word replacement" do
    fab!(:censored_word) do
      Fabricate(:watched_word, word: "censored", action: WatchedWord.actions[:censor])
    end
    fab!(:replaced_word) do
      Fabricate(
        :watched_word,
        word: "to replace",
        replacement: "replaced",
        action: WatchedWord.actions[:replace],
      )
    end
    fab!(:link_word) do
      Fabricate(
        :watched_word,
        word: "https://notdiscourse.org",
        replacement: "https://discourse.org",
        action: WatchedWord.actions[:link],
      )
    end

    it "censors text" do
      expect(described_class.censor_text("a censored word")).to eq(
        "a #{described_class::REPLACEMENT_LETTER * 8} word",
      )
    end

    it "replaces text" do
      expect(described_class.replace_text("a word to replace meow")).to eq("a word replaced meow")
    end

    it "replaces links" do
      expect(described_class.replace_link("please visit https://notdiscourse.org meow")).to eq(
        "please visit https://discourse.org meow",
      )
    end

    describe ".apply_to_text" do
      it "replaces all types of words" do
        text = "hello censored world to replace https://notdiscourse.org"
        expected =
          "hello #{described_class::REPLACEMENT_LETTER * 8} world replaced https://discourse.org"
        expect(described_class.apply_to_text(text)).to eq(expected)
      end

      context "when watched_words_regular_expressions = true" do
        it "replaces captured non-word prefix" do
          SiteSetting.watched_words_regular_expressions = true
          Fabricate(
            :watched_word,
            word: "\\Wplaceholder",
            replacement: "replacement",
            action: WatchedWord.actions[:replace],
          )

          text = "is \tplaceholder in https://notdiscourse.org"
          expected = "is replacement in https://discourse.org"
          expect(described_class.apply_to_text(text)).to eq(expected)
        end
      end

      context "when watched_words_regular_expressions = false" do
        it "maintains non-word character prefix" do
          SiteSetting.watched_words_regular_expressions = false

          text = "to replace and\thttps://notdiscourse.org"
          expected = "replaced and\thttps://discourse.org"
          expect(described_class.apply_to_text(text)).to eq(expected)
        end
      end
    end
  end
end
