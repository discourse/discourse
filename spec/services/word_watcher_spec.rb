# frozen_string_literal: true

RSpec.describe WordWatcher do
  let(:raw) { <<~RAW.strip }
      Do you like liquorice?


      I really like them. One could even say that I am *addicted* to liquorice. And if
      you can mix it up with some anise, then I'm in heaven ;)
    RAW

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
        },
        word2 => {
          case_sensitive: true,
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
        },
      )
    end

    it "returns an empty hash when no words are present" do
      expect(described_class.words_for_action(:tag)).to eq({})
    end
  end

  describe ".word_matcher_regexp_list" do
    let!(:word1) { Fabricate(:watched_word, action: WatchedWord.actions[:block]).word }
    let!(:word2) { Fabricate(:watched_word, action: WatchedWord.actions[:block]).word }
    let!(:word3) do
      Fabricate(:watched_word, action: WatchedWord.actions[:block], case_sensitive: true).word
    end
    let!(:word4) do
      Fabricate(:watched_word, action: WatchedWord.actions[:block], case_sensitive: true).word
    end

    context "when watched_words_regular_expressions = true" do
      it "returns the proper regexp" do
        SiteSetting.watched_words_regular_expressions = true
        regexps = described_class.word_matcher_regexp_list(:block)

        expect(regexps).to be_an(Array)
        expect(regexps.map(&:inspect)).to contain_exactly(
          "/(#{word1})|(#{word2})/i",
          "/(#{word3})|(#{word4})/",
        )
      end
    end

    context "when watched_words_regular_expressions = false" do
      it "returns the proper regexp" do
        SiteSetting.watched_words_regular_expressions = false
        regexps = described_class.word_matcher_regexp_list(:block)

        expect(regexps).to be_an(Array)
        expect(regexps.map(&:inspect)).to contain_exactly(
          "/(?:\\W|^)(#{word1}|#{word2})(?=\\W|$)/i",
          "/(?:\\W|^)(#{word3}|#{word4})(?=\\W|$)/",
        )
      end

      it "is empty for an action without watched words" do
        regexps = described_class.word_matcher_regexp_list(:censor)

        expect(regexps).to be_an(Array)
        expect(regexps).to be_empty
      end
    end

    context "when regular expression is invalid" do
      before do
        SiteSetting.watched_words_regular_expressions = true
        Fabricate(:watched_word, word: "Test[\S*", action: WatchedWord.actions[:block])
      end

      it "does not raise an exception by default" do
        expect { described_class.word_matcher_regexp_list(:block) }.not_to raise_error
      end

      it "raises an exception with raise_errors set to true" do
        expect {
          described_class.word_matcher_regexp_list(:block, raise_errors: true)
        }.to raise_error(RegexpError)
      end
    end
  end

  describe "#word_matches_for_action?" do
    it "is falsey when there are no watched words" do
      expect(described_class.new(raw).word_matches_for_action?(:require_approval)).to be_falsey
    end

    context "with watched words" do
      fab!(:anise) do
        Fabricate(:watched_word, word: "anise", action: WatchedWord.actions[:require_approval])
      end

      it "is falsey without a match" do
        expect(
          described_class.new("No liquorice for me, thanks...").word_matches_for_action?(
            :require_approval,
          ),
        ).to be_falsey
      end

      it "is returns matched words if there's a match" do
        matches = described_class.new(raw).word_matches_for_action?(:require_approval)
        expect(matches).to be_truthy
        expect(matches[1]).to eq(anise.word)
      end

      it "finds at start of string" do
        matches =
          described_class.new("#{anise.word} is garbage").word_matches_for_action?(
            :require_approval,
          )
        expect(matches[1]).to eq(anise.word)
      end

      it "finds at end of string" do
        matches =
          described_class.new("who likes #{anise.word}").word_matches_for_action?(:require_approval)
        expect(matches[1]).to eq(anise.word)
      end

      it "finds non-letters in place of letters" do
        Fabricate(:watched_word, word: "co(onut", action: WatchedWord.actions[:require_approval])

        matches =
          described_class.new("This co(onut is delicious.").word_matches_for_action?(
            :require_approval,
          )
        expect(matches[1]).to eq("co(onut")
      end

      it "handles * for wildcards" do
        Fabricate(:watched_word, word: "a**le*", action: WatchedWord.actions[:require_approval])

        matches =
          described_class.new("I acknowledge you.").word_matches_for_action?(:require_approval)
        expect(matches[1]).to eq("acknowledge")
      end

      it "handles word boundary" do
        Fabricate(:watched_word, word: "love", action: WatchedWord.actions[:require_approval])
        expect(
          described_class.new("I Love, bananas.").word_matches_for_action?(:require_approval)[1],
        ).to eq("Love")
        expect(
          described_class.new("I LOVE; apples.").word_matches_for_action?(:require_approval)[1],
        ).to eq("LOVE")
        expect(
          described_class.new("love: is a thing.").word_matches_for_action?(:require_approval)[1],
        ).to eq("love")
        expect(
          described_class.new("I love. oranges").word_matches_for_action?(:require_approval)[1],
        ).to eq("love")
        expect(
          described_class.new("I :love. pineapples").word_matches_for_action?(:require_approval)[1],
        ).to eq("love")
        expect(
          described_class.new("peace ,love and understanding.").word_matches_for_action?(
            :require_approval,
          )[
            1
          ],
        ).to eq("love")
      end

      context "when there are multiple matches" do
        context "with non regexp words" do
          it "lists all matching words" do
            %w[bananas hate hates].each do |word|
              Fabricate(:watched_word, word: word, action: WatchedWord.actions[:block])
            end

            matches =
              described_class.new("I hate bananas").word_matches_for_action?(
                :block,
                all_matches: true,
              )
            expect(matches).to contain_exactly("hate", "bananas")

            matches =
              described_class.new("She hates bananas too").word_matches_for_action?(
                :block,
                all_matches: true,
              )
            expect(matches).to contain_exactly("hates", "bananas")
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

            matches =
              described_class.new("pine pineapples apples").word_matches_for_action?(
                :block,
                all_matches: true,
              )
            expect(matches).to contain_exactly("pineapples", "apples")

            matches =
              described_class.new(
                "go watched watch ed ing move d moveed moved moving",
              ).word_matches_for_action?(:block, all_matches: true)
            expect(matches).to contain_exactly(*%w[watched watch move moved])
          end
        end
      end

      context "when word is an emoji" do
        it "handles emoji" do
          Fabricate(:watched_word, word: ":joy:", action: WatchedWord.actions[:require_approval])

          matches =
            described_class.new("Lots of emojis here :joy:").word_matches_for_action?(
              :require_approval,
            )
          expect(matches[1]).to eq(":joy:")
        end

        it "handles unicode emoji" do
          Fabricate(:watched_word, word: "🎃", action: WatchedWord.actions[:require_approval])

          matches =
            described_class.new("Halloween party! 🎃").word_matches_for_action?(:require_approval)
          expect(matches[1]).to eq("🎃")
        end

        it "handles emoji skin tone" do
          Fabricate(
            :watched_word,
            word: ":woman:t5:",
            action: WatchedWord.actions[:require_approval],
          )

          matches =
            described_class.new("To Infinity and beyond! 🚀 :woman:t5:").word_matches_for_action?(
              :require_approval,
            )
          expect(matches[1]).to eq(":woman:t5:")
        end
      end

      context "when word is a regular expression" do
        before { SiteSetting.watched_words_regular_expressions = true }

        it "supports regular expressions on word boundaries" do
          Fabricate(:watched_word, word: /\btest\b/, action: WatchedWord.actions[:block])

          matches = described_class.new("this is not a test.").word_matches_for_action?(:block)
          expect(matches[0]).to eq("test")
        end

        it "supports regular expressions as a site setting" do
          Fabricate(
            :watched_word,
            word: /tro[uo]+t/,
            action: WatchedWord.actions[:require_approval],
          )

          matches =
            described_class.new("Evil Trout is cool").word_matches_for_action?(:require_approval)
          expect(matches[0]).to eq("Trout")

          matches =
            described_class.new("Evil Troot is cool").word_matches_for_action?(:require_approval)
          expect(matches[0]).to eq("Troot")

          matches = described_class.new("trooooooooot").word_matches_for_action?(:require_approval)
          expect(matches[0]).to eq("trooooooooot")
        end

        it "support uppercase" do
          Fabricate(:watched_word, word: /a\S+ce/, action: WatchedWord.actions[:require_approval])

          matches = described_class.new("Amazing place").word_matches_for_action?(:require_approval)
          expect(matches).to be_nil

          matches =
            described_class.new("Amazing applesauce").word_matches_for_action?(:require_approval)
          expect(matches[0]).to eq("applesauce")

          matches =
            described_class.new("Amazing AppleSauce").word_matches_for_action?(:require_approval)
          expect(matches[0]).to eq("AppleSauce")
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

            matches =
              described_class.new(
                "PUBLIC: Discourse is great for public discourse",
              ).word_matches_for_action?(:block, all_matches: true)
            expect(matches).to contain_exactly("PUBLIC", "Discourse", "public")
          end
        end

        context "when watched_words_regular_expressions = false" do
          it "repects case sensitivity flag in matching" do
            SiteSetting.watched_words_regular_expressions = false
            Fabricate(:watched_word, word: "private", action: WatchedWord.actions[:block])

            matches =
              described_class.new(
                "PRIVATE: Discourse is also great private discourse",
              ).word_matches_for_action?(:block, all_matches: true)

            expect(matches).to contain_exactly("PRIVATE", "Discourse", "private")
          end
        end
      end
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
