# frozen_string_literal: true

RSpec.describe WordWatcher do
  let(:raw) { "Do you like liquorice?\n\nI really like them. One could even say that I am *addicted* to liquorice. And if\nyou can mix it up with some anise, then I'm in heaven ;)" }

  after do
    Discourse.redis.flushdb
  end

  describe '.word_matcher_regexp' do
    let!(:word1) { Fabricate(:watched_word, action: WatchedWord.actions[:block]).word }
    let!(:word2) { Fabricate(:watched_word, action: WatchedWord.actions[:block]).word }

    context 'format of the result regexp' do
      it "is correct when watched_words_regular_expressions = true" do
        SiteSetting.watched_words_regular_expressions = true
        regexp = described_class.word_matcher_regexp(:block)
        expect(regexp.inspect).to eq("/(#{word1})|(#{word2})/i")
      end

      it "is correct when watched_words_regular_expressions = false" do
        SiteSetting.watched_words_regular_expressions = false
        regexp = described_class.word_matcher_regexp(:block)
        expect(regexp.inspect).to eq("/(?:\\W|^)(#{word1}|#{word2})(?=\\W|$)/i")
      end
    end
  end

  describe "#word_matches_for_action?" do
    it "is falsey when there are no watched words" do
      expect(described_class.new(raw).word_matches_for_action?(:require_approval)).to be_falsey
    end

    context "with watched words" do
      fab!(:anise) { Fabricate(:watched_word, word: "anise", action: WatchedWord.actions[:require_approval]) }

      it "is falsey without a match" do
        expect(described_class.new("No liquorice for me, thanks...").word_matches_for_action?(:require_approval)).to be_falsey
      end

      it "is returns matched words if there's a match" do
        matches = described_class.new(raw).word_matches_for_action?(:require_approval)
        expect(matches).to be_truthy
        expect(matches[1]).to eq(anise.word)
      end

      it "finds at start of string" do
        matches = described_class.new("#{anise.word} is garbage").word_matches_for_action?(:require_approval)
        expect(matches[1]).to eq(anise.word)
      end

      it "finds at end of string" do
        matches = described_class.new("who likes #{anise.word}").word_matches_for_action?(:require_approval)
        expect(matches[1]).to eq(anise.word)
      end

      it "finds non-letters in place of letters" do
        Fabricate(:watched_word, word: "co(onut", action: WatchedWord.actions[:require_approval])

        matches = described_class.new("This co(onut is delicious.").word_matches_for_action?(:require_approval)
        expect(matches[1]).to eq("co(onut")
      end

      it "handles * for wildcards" do
        Fabricate(:watched_word, word: "a**le*", action: WatchedWord.actions[:require_approval])

        matches = described_class.new("I acknowledge you.").word_matches_for_action?(:require_approval)
        expect(matches[1]).to eq("acknowledge")
      end

      context "word boundary" do
        it "handles word boundary" do
          Fabricate(:watched_word, word: "love", action: WatchedWord.actions[:require_approval])
          expect(described_class.new("I Love, bananas.").word_matches_for_action?(:require_approval)[1]).to eq("Love")
          expect(described_class.new("I LOVE; apples.").word_matches_for_action?(:require_approval)[1]).to eq("LOVE")
          expect(described_class.new("love: is a thing.").word_matches_for_action?(:require_approval)[1]).to eq("love")
          expect(described_class.new("I love. oranges").word_matches_for_action?(:require_approval)[1]).to eq("love")
          expect(described_class.new("I :love. pineapples").word_matches_for_action?(:require_approval)[1]).to eq("love")
          expect(described_class.new("peace ,love and understanding.").word_matches_for_action?(:require_approval)[1]).to eq("love")
        end
      end

      context 'multiple matches' do
        context 'non regexp words' do
          it 'lists all matching words' do
            %w{bananas hate hates}.each do |word|
              Fabricate(:watched_word, word: word, action: WatchedWord.actions[:block])
            end

            matches = described_class.new("I hate bananas").word_matches_for_action?(:block, all_matches: true)
            expect(matches).to contain_exactly('hate', 'bananas')

            matches = described_class.new("She hates bananas too").word_matches_for_action?(:block, all_matches: true)
            expect(matches).to contain_exactly('hates', 'bananas')
          end
        end

        context 'regexp words' do
          before do
            SiteSetting.watched_words_regular_expressions = true
          end

          it 'lists all matching patterns' do
            Fabricate(:watched_word, word: "(pine)?apples", action: WatchedWord.actions[:block])
            Fabricate(:watched_word, word: "((move|store)(d)?)|((watch|listen)(ed|ing)?)", action: WatchedWord.actions[:block])

            matches = described_class.new("pine pineapples apples").word_matches_for_action?(:block, all_matches: true)
            expect(matches).to contain_exactly('pineapples', 'apples')

            matches = described_class.new("go watched watch ed ing move d moveed moved moving").word_matches_for_action?(:block, all_matches: true)
            expect(matches).to contain_exactly(*%w{watched watch move moved})
          end
        end
      end

      context "emojis" do
        it "handles emoji" do
          Fabricate(:watched_word, word: ":joy:", action: WatchedWord.actions[:require_approval])

          matches = described_class.new("Lots of emojis here :joy:").word_matches_for_action?(:require_approval)
          expect(matches[1]).to eq(":joy:")
        end

        it "handles unicode emoji" do
          Fabricate(:watched_word, word: "🎃", action: WatchedWord.actions[:require_approval])

          matches = described_class.new("Halloween party! 🎃").word_matches_for_action?(:require_approval)
          expect(matches[1]).to eq("🎃")
        end

        it "handles emoji skin tone" do
          Fabricate(:watched_word, word: ":woman:t5:", action: WatchedWord.actions[:require_approval])

          matches = described_class.new("To Infinity and beyond! 🚀 :woman:t5:").word_matches_for_action?(:require_approval)
          expect(matches[1]).to eq(":woman:t5:")
        end
      end

      context "regular expressions" do
        before do
          SiteSetting.watched_words_regular_expressions = true
        end

        it "supports regular expressions on word boundaries" do
          Fabricate(
            :watched_word,
            word: /\btest\b/,
            action: WatchedWord.actions[:block]
          )

          matches = described_class.new("this is not a test.").word_matches_for_action?(:block)
          expect(matches[0]).to eq("test")
        end

        it "supports regular expressions as a site setting" do
          Fabricate(
            :watched_word,
            word: /tro[uo]+t/,
            action: WatchedWord.actions[:require_approval]
          )

          matches = described_class.new("Evil Trout is cool").word_matches_for_action?(:require_approval)
          expect(matches[0]).to eq("Trout")

          matches = described_class.new("Evil Troot is cool").word_matches_for_action?(:require_approval)
          expect(matches[0]).to eq("Troot")

          matches = described_class.new("trooooooooot").word_matches_for_action?(:require_approval)
          expect(matches[0]).to eq("trooooooooot")
        end

        it "support uppercase" do
          Fabricate(
            :watched_word,
            word: /a\S+ce/,
            action: WatchedWord.actions[:require_approval]
          )

          matches = described_class.new('Amazing place').word_matches_for_action?(:require_approval)
          expect(matches).to be_nil

          matches = described_class.new('Amazing applesauce').word_matches_for_action?(:require_approval)
          expect(matches[0]).to eq('applesauce')

          matches = described_class.new('Amazing AppleSauce').word_matches_for_action?(:require_approval)
          expect(matches[0]).to eq('AppleSauce')
        end
      end

    end
  end

  describe ".apply_to_text" do
    fab!(:censored_word) { Fabricate(:watched_word, word: "censored", action: WatchedWord.actions[:censor]) }
    fab!(:replaced_word) { Fabricate(:watched_word, word: "to replace", replacement: "replaced", action: WatchedWord.actions[:replace]) }
    fab!(:link_word) { Fabricate(:watched_word, word: "https://notdiscourse.org", replacement: "https://discourse.org", action: WatchedWord.actions[:link]) }

    it "replaces all types of words" do
      text = "hello censored world to replace https://notdiscourse.org"
      expected = "hello #{described_class::REPLACEMENT_LETTER * 8} world replaced https://discourse.org"
      expect(described_class.apply_to_text(text)).to eq(expected)
    end
  end
end
