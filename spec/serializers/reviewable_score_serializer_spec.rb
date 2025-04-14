# frozen_string_literal: true

RSpec.describe ReviewableScoreSerializer do
  fab!(:reviewable) { Fabricate(:reviewable_flagged_post) }
  fab!(:admin)

  reasons = %w[
    post_count
    trust_level
    new_topics_unless_trust_level
    fast_typer
    auto_silence_regex
    staged
    must_approve_users
    invite_only
    email_spam
    suspect_user
    contains_media
    watched_word
  ]

  describe "#reason" do
    context "with regular links" do
      it "adds a link for watched words" do
        serialized = serialized_score("watched_word")
        link_url = "#{Discourse.base_url}/admin/customize/watched_words"
        watched_words_link =
          "<a href=\"#{link_url}\">#{I18n.t("reviewables.reasons.links.watched_word")}</a>"

        expect(serialized.reason).to include(watched_words_link)
      end

      it "adds a link for category settings" do
        category = Fabricate(:category, name: "Reviewable Category", slug: "reviewable-category")
        reviewable.category = category
        serialized = serialized_score("category")
        link_url = "#{Discourse.base_url}/c/#{category.slug}/edit/settings"
        category_link =
          "<a href=\"#{link_url}\">#{I18n.t("reviewables.reasons.links.category")}</a>"

        expect(serialized.reason).to include(category_link)
      end
    end

    context "with site setting links" do
      reasons
        .reject { |r| r == "watched_word" }
        .each do |r|
          it "adds a link to a site setting for the #{r} reason" do
            serialized = serialized_score(r)
            setting_name = described_class::REASONS_AND_SETTINGS[r.to_sym]
            link_url =
              "#{Discourse.base_url}/admin/site_settings/category/all_results?filter=#{setting_name}"
            link = "<a href=\"#{link_url}\">#{setting_name.gsub("_", " ")}</a>"

            expect(serialized.reason).to include(link)
          end
        end
    end

    context "with custom reasons" do
      it "serializes it without doing any translation" do
        custom = "completely custom flag reason"
        serialized = serialized_score(custom)

        expect(serialized.reason).to eq(custom)
      end
    end

    context "with watched words" do
      let(:link) do
        "<a href=\"#{Discourse.base_url}/admin/customize/watched_words\">#{I18n.t("reviewables.reasons.links.watched_word")}</a>"
      end
      it "tries to guess the watched words if they weren't recorded at the time of flagging" do
        raw = "I'm a post with some bad words like 'bad' and 'words'."
        reviewable.target = Fabricate(:post, raw:)

        score = serialized_score("watched_word")

        Fabricate(:watched_word, action: WatchedWord.actions[:flag], word: "bad")
        Fabricate(:watched_word, action: WatchedWord.actions[:flag], word: "words")

        expect(score.reason).to include("bad, words")

        expect(reviewable.target.raw).to eq(raw)
      end

      it "handles guessing the watched words when the post hasn't been created yet" do
        queued_reviewable = Fabricate(:reviewable_queued_post_topic)
        raw = queued_reviewable.payload["raw"].clone
        reviewable_score =
          ReviewableScore.new(reviewable: queued_reviewable, reason: "watched_word")

        Fabricate(:watched_word, action: WatchedWord.actions[:flag], word: "contents")
        Fabricate(:watched_word, action: WatchedWord.actions[:flag], word: "title")

        result = described_class.new(reviewable_score, scope: Guardian.new(admin), root: nil)
        expect(result.reason).to include("contents, title")
        expect(queued_reviewable.payload["raw"]).to eq(raw)
      end

      it "uses the no-context message if the post has no watched words" do
        reviewable.target = Fabricate(:post, raw: "This post contains no bad words.")

        score = serialized_score("watched_word")

        Fabricate(:watched_word, action: WatchedWord.actions[:flag], word: "superbad")

        expect(score.reason).to eq(
          I18n.t(
            "reviewables.reasons.no_context.watched_word",
            link: link,
            default: "watched_word",
          ),
        )
      end
    end
  end

  describe "#reason_type" do
    reasons.each do |reason|
      it "returns the correct reason type for #{reason}" do
        serialized = serialized_score(reason)
        expect(serialized.reason_type).to eq(reason)
      end
    end
  end

  describe "#reason_data" do
    reasons
      .reject { |r| r == "watched_word" }
      .each do |reason|
        it "returns nil for #{reason}" do
          serialized = serialized_score(reason)
          expect(serialized.reason_data).to be_nil
        end
      end

    it "returns the watched words found for the watched_word reason" do
      raw = "I'm a post with some bad words like 'bad' and 'words'."
      reviewable.target = Fabricate(:post, raw:)

      score = serialized_score("watched_word")

      Fabricate(:watched_word, action: WatchedWord.actions[:flag], word: "bad")
      Fabricate(:watched_word, action: WatchedWord.actions[:flag], word: "words")

      expect(score.reason_data).to include("bad", "words")
    end
  end

  describe "#setting_name_for_reason" do
    after { DiscoursePluginRegistry.reset_register!(:reviewable_score_links) }

    describe "when a plugin adds a setting name to linkify" do
      it "gets the setting name from the registry" do
        reason = :plugin_reason
        setting_name = "max_username_length"
        DiscoursePluginRegistry.register_reviewable_score_link(
          { reason: reason, setting: setting_name },
          Plugin::Instance.new,
        )

        score = serialized_score(reason)

        expect(score.setting_name_for_reason(reason)).to eq(setting_name)
      end
    end
  end

  def serialized_score(reason)
    score = ReviewableScore.new(reviewable: reviewable, reason: reason)

    described_class.new(score, scope: Guardian.new(admin), root: nil)
  end
end
