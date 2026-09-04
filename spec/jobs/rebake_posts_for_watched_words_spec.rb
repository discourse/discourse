# frozen_string_literal: true

RSpec.describe Jobs::RebakePostsForWatchedWords do
  describe ".enqueue_for" do
    it "enqueues display actions as one job" do
      censor_word = WatchedWord.create_or_update_word(word: "censor-me", action_key: :censor)
      replace_word =
        WatchedWord.create_or_update_word(
          word: "replace-me",
          action_key: :replace,
          replacement: "replacement",
        )

      expect_enqueued_with(
        job: described_class,
        args: {
          words: [censor_word.word, replace_word.word],
        },
      ) { described_class.enqueue_for([censor_word, replace_word]) }
    end

    it "does not enqueue moderation actions or wildcard words" do
      block_word = WatchedWord.create_or_update_word(word: "block-me", action_key: :block)
      wildcard_word = WatchedWord.create_or_update_word(word: "*wildcard", action_key: :censor)

      expect_not_enqueued_with(job: described_class) do
        described_class.enqueue_for([block_word, wildcard_word])
      end
    end
  end

  describe "#execute" do
    it "rebakes old matching posts without rebaking unrelated posts" do
      matching_post = Fabricate(:post, raw: "contains a retroactive word")
      unrelated_post = Fabricate(:post, raw: "contains something else")
      unrelated_baked_at = 1.day.ago
      unrelated_post.update_column(:baked_at, unrelated_baked_at)

      Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: "retroactive")

      described_class.new.execute(words: ["retroactive"])

      expect(matching_post.reload.cooked).to eq(PrettyText.cook(matching_post.raw))
      expect(matching_post.cooked).not_to include("retroactive")
      expect(unrelated_post.reload.baked_at).to eq_time(unrelated_baked_at)
    end

    it "restores old posts after a display rule is deleted" do
      watched_word =
        Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: "temporary")
      post = Fabricate(:post, raw: "a temporary rule")
      expect(post.cooked).not_to include("temporary")

      watched_word.destroy!
      WordWatcher.clear_cache!
      described_class.new.execute(words: ["temporary"])

      expect(post.reload.cooked).to eq("<p>a temporary rule</p>")
    end

    it "continues in another job after processing a full batch" do
      first_post = Fabricate(:post, raw: "batch target one")
      second_post = Fabricate(:post, raw: "batch target two")
      Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: "target")

      stub_const(described_class, "BATCH_SIZE", 1) do
        expect_enqueued_with(
          job: described_class,
          args: {
            words: ["target"],
            after_post_id: first_post.id,
            max_post_id: second_post.id,
          },
        ) do
          described_class.new.execute(
            words: ["target"],
            after_post_id: first_post.id - 1,
            max_post_id: second_post.id,
          )
        end
      end

      expect(first_post.reload.cooked).not_to include("target")
      expect(second_post.reload.cooked).to include("target")
    end

    it "advances to the end of a scan window when fewer than a full batch match" do
      window_post = Fabricate(:post, raw: "window target")
      later_post = Fabricate(:post, raw: "later target")
      Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: "target")

      stub_const(described_class, "SCAN_WINDOW_SIZE", 1) do
        expect_enqueued_with(
          job: described_class,
          args: {
            words: ["target"],
            after_post_id: window_post.id,
            max_post_id: later_post.id,
          },
        ) do
          described_class.new.execute(
            words: ["target"],
            after_post_id: window_post.id - 1,
            max_post_id: later_post.id,
          )
        end
      end

      expect(window_post.reload.cooked).not_to include("target")
      expect(later_post.reload.cooked).to include("target")
    end

    it "finds matches across bounded groups of word predicates" do
      matching_post = Fabricate(:post, raw: "contains the second word")
      Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: "second")

      stub_const(described_class, "PATTERN_BATCH_SIZE", 1) do
        described_class.new.execute(words: %w[absent second])
      end

      expect(matching_post.reload.cooked).not_to include("second")
    end
  end
end
