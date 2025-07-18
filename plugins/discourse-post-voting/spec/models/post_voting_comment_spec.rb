# frozen_string_literal: true

require "rails_helper"

describe PostVotingComment do
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:user)
  fab!(:tag)

  before { SiteSetting.post_voting_enabled = true }

  describe "validations" do
    it "does not allow comments to be created when post is in reply to another post" do
      post_2 = Fabricate(:post, topic: topic)

      SiteSetting.post_voting_enabled = false

      post_3 = Fabricate(:post, topic: topic, reply_to_post_number: post_2.post_number)

      SiteSetting.post_voting_enabled = true

      comment = PostVotingComment.new(raw: "this is a **post**", post: post_3, user: user)

      expect(comment.valid?).to eq(false)
      expect(comment.errors.full_messages).to contain_exactly(
        I18n.t("post_voting.comment.errors.not_permitted"),
      )
    end

    it "does not allow comments to be created when SiteSetting.post_voting_comment_limit_per_post has been reached" do
      SiteSetting.post_voting_comment_limit_per_post = 1

      PostVotingComment.create!(raw: "this is a **post**", post: post, user: user)
      comment = PostVotingComment.new(raw: "this is a **post**", post: post, user: user)

      expect(comment.valid?).to eq(false)

      expect(comment.errors.full_messages).to contain_exactly(
        I18n.t(
          "post_voting.comment.errors.limit_exceeded",
          limit: SiteSetting.post_voting_comment_limit_per_post,
        ),
      )
    end

    it "does not allow comment to be created when raw does not meet min_post_length site setting" do
      SiteSetting.min_post_length = 5

      comment = PostVotingComment.new(raw: "1234", post: post, user: user)

      expect(comment.valid?).to eq(false)
      expect(comment.errors[:raw]).to eq([I18n.t("errors.messages.too_short", count: 5)])
    end

    it "does not allow comment to be created when raw length exceeds post_voting_comment_max_raw_length site setting" do
      max = SiteSetting.post_voting_comment_max_raw_length = 5
      raw = "this string is too long"

      post_voting_comment = PostVotingComment.new(raw: raw, post: post, user: user)

      expect(post_voting_comment.valid?).to eq(false)
      expect(post_voting_comment.errors[:raw]).to eq(
        [I18n.t("errors.messages.too_long_validation", count: max, length: raw.length)],
      )
    end

    it "does not allow comment to be created when raw does not pass TextSentinel check" do
      post_voting_comment = PostVotingComment.new(raw: "ALL CAPS STRING", post: post, user: user)

      expect(post_voting_comment.valid?).to eq(false)
      expect(post_voting_comment.errors[:raw]).to eq([I18n.t("is_invalid")])
    end

    it "does not allow comment to be created when raw contains a blocked watch word" do
      watched_word = Fabricate(:watched_word, action: WatchedWord.actions[:block])

      post_voting_comment =
        PostVotingComment.new(raw: "contains #{watched_word.word}", post: post, user: user)

      expect(post_voting_comment.valid?).to eq(false)
      expect(post_voting_comment.errors[:base]).to eq(
        [I18n.t("contains_blocked_word", word: watched_word.word)],
      )
    end
  end

  describe "callbacks" do
    it "cooks raw before saving" do
      post_voting_comment = PostVotingComment.new(raw: "this is a **post**", post: post, user: user)

      expect(post_voting_comment.valid?).to eq(true)
      expect(post_voting_comment.cooked).to eq("<p>this is a <strong>post</strong></p>")
      expect(post_voting_comment.cooked_version).to eq(described_class::COOKED_VERSION)
    end
  end

  describe ".cook" do
    it "supports emphasis markdown rule" do
      post_voting_comment = Fabricate(:post_voting_comment, post: post, raw: "**bold**")

      expect(post_voting_comment.cooked).to eq("<p><strong>bold</strong></p>")
    end

    it "supports backticks markdown rule" do
      post_voting_comment = Fabricate(:post_voting_comment, post: post, raw: "`test`")

      expect(post_voting_comment.cooked).to eq("<p><code>test</code></p>")
    end

    it "supports link markdown rule" do
      post_voting_comment =
        Fabricate(:post_voting_comment, post: post, raw: "[test link](https://www.example.com)")

      expect(post_voting_comment.cooked).to eq(
        "<p><a href=\"https://www.example.com\" rel=\"noopener nofollow ugc\">test link</a></p>",
      )
    end

    it "supports linkify markdown rule" do
      post_voting_comment =
        Fabricate(:post_voting_comment, post: post, raw: "https://www.example.com")

      expect(post_voting_comment.cooked).to eq(
        "<p><a href=\"https://www.example.com\" rel=\"noopener nofollow ugc\">https://www.example.com</a></p>",
      )
    end

    it "supports emoji markdown engine" do
      post_voting_comment = Fabricate(:post_voting_comment, post: post, raw: ":grin: abcde")

      expect(post_voting_comment.cooked).to eq(
        "<p><img src=\"/images/emoji/twitter/grin.png?v=#{Emoji::EMOJI_VERSION}\" title=\":grin:\" class=\"emoji\" alt=\":grin:\" loading=\"lazy\" width=\"20\" height=\"20\"> abcde</p>",
      )
    end

    it "supports censored markdown engine" do
      watched_word = Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: "testing")

      post_voting_comment = Fabricate(:post_voting_comment, post: post, raw: watched_word.word)

      expect(post_voting_comment.cooked).to eq("<p>■■■■■■■</p>")
    end

    it "removes newlines from raw as comments should only support a single paragraph" do
      post_voting_comment = Fabricate(:post_voting_comment, post: post, raw: <<~RAW)
      line 1

      line 2
      RAW

      expect(post_voting_comment.cooked).to eq("<p>line 1 line 2</p>")
    end
  end
end
