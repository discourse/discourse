# frozen_string_literal: true

RSpec.describe ReviewableScoreSerializer do
  fab!(:reviewable, :reviewable_flagged_post)
  fab!(:admin)

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
      it "adds a link to a site setting for the post_count reason" do
        serialized = serialized_score("post_count")
        setting_name = described_class::REASONS_AND_SETTINGS[:post_count]
        link_url =
          "#{Discourse.base_url}/admin/site_settings/category/all_results?filter=#{setting_name}"
        link = "<a href=\"#{link_url}\">#{setting_name.gsub("_", " ")}</a>"

        expect(serialized.reason).to include(link)
      end

      it "adds a link to a site setting for the trust_level reason" do
        serialized = serialized_score("trust_level")
        setting_name = described_class::REASONS_AND_SETTINGS[:trust_level]
        link_url =
          "#{Discourse.base_url}/admin/site_settings/category/all_results?filter=#{setting_name}"
        link = "<a href=\"#{link_url}\">#{setting_name.gsub("_", " ")}</a>"

        expect(serialized.reason).to include(link)
      end

      it "adds a link to a site setting for the new_topics_unless_trust_level reason" do
        serialized = serialized_score("new_topics_unless_trust_level")
        setting_name = described_class::REASONS_AND_SETTINGS[:new_topics_unless_trust_level]
        link_url =
          "#{Discourse.base_url}/admin/site_settings/category/all_results?filter=#{setting_name}"
        link = "<a href=\"#{link_url}\">#{setting_name.gsub("_", " ")}</a>"

        expect(serialized.reason).to include(link)
      end

      it "adds a link to a site setting for the fast_typer reason" do
        serialized = serialized_score("fast_typer")
        setting_name = described_class::REASONS_AND_SETTINGS[:fast_typer]
        link_url =
          "#{Discourse.base_url}/admin/site_settings/category/all_results?filter=#{setting_name}"
        link = "<a href=\"#{link_url}\">#{setting_name.gsub("_", " ")}</a>"

        expect(serialized.reason).to include(link)
      end

      it "adds a link to a site setting for the auto_silence_regex reason" do
        serialized = serialized_score("auto_silence_regex")
        setting_name = described_class::REASONS_AND_SETTINGS[:auto_silence_regex]
        link_url =
          "#{Discourse.base_url}/admin/site_settings/category/all_results?filter=#{setting_name}"
        link = "<a href=\"#{link_url}\">#{setting_name.gsub("_", " ")}</a>"

        expect(serialized.reason).to include(link)
      end

      it "adds a link to a site setting for the staged reason" do
        serialized = serialized_score("staged")
        setting_name = described_class::REASONS_AND_SETTINGS[:staged]
        link_url =
          "#{Discourse.base_url}/admin/site_settings/category/all_results?filter=#{setting_name}"
        link = "<a href=\"#{link_url}\">#{setting_name.gsub("_", " ")}</a>"

        expect(serialized.reason).to include(link)
      end

      it "adds a link to a site setting for the must_approve_users reason" do
        serialized = serialized_score("must_approve_users")
        setting_name = described_class::REASONS_AND_SETTINGS[:must_approve_users]
        link_url =
          "#{Discourse.base_url}/admin/site_settings/category/all_results?filter=#{setting_name}"
        link = "<a href=\"#{link_url}\">#{setting_name.gsub("_", " ")}</a>"

        expect(serialized.reason).to include(link)
      end

      it "adds a link to a site setting for the invite_only reason" do
        serialized = serialized_score("invite_only")
        setting_name = described_class::REASONS_AND_SETTINGS[:invite_only]
        link_url =
          "#{Discourse.base_url}/admin/site_settings/category/all_results?filter=#{setting_name}"
        link = "<a href=\"#{link_url}\">#{setting_name.gsub("_", " ")}</a>"

        expect(serialized.reason).to include(link)
      end

      it "adds a link to a site setting for the email_spam reason" do
        serialized = serialized_score("email_spam")
        setting_name = described_class::REASONS_AND_SETTINGS[:email_spam]
        link_url =
          "#{Discourse.base_url}/admin/site_settings/category/all_results?filter=#{setting_name}"
        link = "<a href=\"#{link_url}\">#{setting_name.gsub("_", " ")}</a>"

        expect(serialized.reason).to include(link)
      end

      it "adds a link to a site setting for the suspect_user reason" do
        serialized = serialized_score("suspect_user")
        setting_name = described_class::REASONS_AND_SETTINGS[:suspect_user]
        link_url =
          "#{Discourse.base_url}/admin/site_settings/category/all_results?filter=#{setting_name}"
        link = "<a href=\"#{link_url}\">#{setting_name.gsub("_", " ")}</a>"

        expect(serialized.reason).to include(link)
      end

      it "adds a link to a site setting for the contains_media reason" do
        serialized = serialized_score("contains_media")
        setting_name = described_class::REASONS_AND_SETTINGS[:contains_media]
        link_url =
          "#{Discourse.base_url}/admin/site_settings/category/all_results?filter=#{setting_name}"
        link = "<a href=\"#{link_url}\">#{setting_name.gsub("_", " ")}</a>"

        expect(serialized.reason).to include(link)
      end
    end

    context "with a fast_typer reason" do
      it "includes the recorded typing duration" do
        reviewable = Fabricate(:reviewable_queued_post, payload: { "typing_duration_msecs" => 500 })
        score = ReviewableScore.new(reviewable:, reason: "fast_typer")
        serialized = described_class.new(score, scope: Guardian.new(admin), root: nil)

        expect(serialized.reason).to include("(0.5 seconds)")
      end

      it "drops trailing decimals when the duration is a whole number of seconds" do
        reviewable =
          Fabricate(:reviewable_queued_post, payload: { "typing_duration_msecs" => 3000 })
        score = ReviewableScore.new(reviewable:, reason: "fast_typer")
        serialized = described_class.new(score, scope: Guardian.new(admin), root: nil)

        expect(serialized.reason).to include("(3 seconds)")
      end

      it "falls back to a message without a typing duration when none was recorded" do
        serialized = serialized_score("fast_typer")

        expect(serialized.reason).to include("typed their first post suspiciously fast,")
        expect(serialized.reason).not_to include("second")
      end
    end

    context "with custom reasons" do
      it "serializes it without doing any translation" do
        custom = "completely custom flag reason"
        serialized = serialized_score(custom)

        expect(serialized.reason).to match_html("<p>#{custom}</p>")
      end

      it "cooks and sanitizes basic Markdown without post-specific transformations" do
        custom = <<~MARKDOWN
          **Details**

          - first
          - second

          first<br>second

          @#{admin.username} :smile:

          <script>alert("unsafe")</script>
        MARKDOWN

        serialized = serialized_score(custom)

        expect(serialized.reason).to match_html(<<~HTML)
          <p><strong>Details</strong></p>
          <ul>
            <li>first</li>
            <li>second</li>
          </ul>
          <p>first<br>second</p>
          <p>@#{admin.username} :smile:</p>
        HTML
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

      it "renders matched words containing HTML and Markdown syntax literally" do
        words = [
          "<notifications@example.discoursemail.com>",
          "[urgent](https://example.com)",
          "**spam**",
        ]
        score =
          ReviewableScore.new(
            reviewable: reviewable,
            reason: "watched_word",
            context: words.join(","),
          )
        serialized = described_class.new(score, scope: admin.guardian, root: nil)
        reason =
          I18n.t(
            "reviewables.reasons.watched_word",
            link: link,
            words: CGI.escapeHTML(words.join(", ")),
            count: words.length,
          )

        expect(serialized.reason).to match_html("<p>#{reason}</p>")
      end

      it "uses the no-context message if the post has no watched words" do
        reviewable.target = Fabricate(:post, raw: "This post contains no bad words.")

        score = serialized_score("watched_word")

        Fabricate(:watched_word, action: WatchedWord.actions[:flag], word: "superbad")

        reason =
          I18n.t("reviewables.reasons.no_context.watched_word", link:, default: "watched_word")

        expect(score.reason).to match_html("<p>#{reason}</p>")
      end
    end
  end

  describe "#reason_type" do
    it "returns the correct reason type for post_count" do
      serialized = serialized_score("post_count")
      expect(serialized.reason_type).to eq("post_count")
    end

    it "returns the correct reason type for trust_level" do
      serialized = serialized_score("trust_level")
      expect(serialized.reason_type).to eq("trust_level")
    end

    it "returns the correct reason type for new_topics_unless_trust_level" do
      serialized = serialized_score("new_topics_unless_trust_level")
      expect(serialized.reason_type).to eq("new_topics_unless_trust_level")
    end

    it "returns the correct reason type for fast_typer" do
      serialized = serialized_score("fast_typer")
      expect(serialized.reason_type).to eq("fast_typer")
    end

    it "returns the correct reason type for auto_silence_regex" do
      serialized = serialized_score("auto_silence_regex")
      expect(serialized.reason_type).to eq("auto_silence_regex")
    end

    it "returns the correct reason type for staged" do
      serialized = serialized_score("staged")
      expect(serialized.reason_type).to eq("staged")
    end

    it "returns the correct reason type for must_approve_users" do
      serialized = serialized_score("must_approve_users")
      expect(serialized.reason_type).to eq("must_approve_users")
    end

    it "returns the correct reason type for invite_only" do
      serialized = serialized_score("invite_only")
      expect(serialized.reason_type).to eq("invite_only")
    end

    it "returns the correct reason type for email_spam" do
      serialized = serialized_score("email_spam")
      expect(serialized.reason_type).to eq("email_spam")
    end

    it "returns the correct reason type for suspect_user" do
      serialized = serialized_score("suspect_user")
      expect(serialized.reason_type).to eq("suspect_user")
    end

    it "returns the correct reason type for contains_media" do
      serialized = serialized_score("contains_media")
      expect(serialized.reason_type).to eq("contains_media")
    end

    it "returns the correct reason type for watched_word" do
      serialized = serialized_score("watched_word")
      expect(serialized.reason_type).to eq("watched_word")
    end
  end

  describe "#reason_data" do
    it "returns nil for post_count" do
      serialized = serialized_score("post_count")
      expect(serialized.reason_data).to be_nil
    end

    it "returns nil for trust_level" do
      serialized = serialized_score("trust_level")
      expect(serialized.reason_data).to be_nil
    end

    it "returns nil for new_topics_unless_trust_level" do
      serialized = serialized_score("new_topics_unless_trust_level")
      expect(serialized.reason_data).to be_nil
    end

    it "returns nil for fast_typer" do
      serialized = serialized_score("fast_typer")
      expect(serialized.reason_data).to be_nil
    end

    it "returns nil for auto_silence_regex" do
      serialized = serialized_score("auto_silence_regex")
      expect(serialized.reason_data).to be_nil
    end

    it "returns nil for staged" do
      serialized = serialized_score("staged")
      expect(serialized.reason_data).to be_nil
    end

    it "returns nil for must_approve_users" do
      serialized = serialized_score("must_approve_users")
      expect(serialized.reason_data).to be_nil
    end

    it "returns nil for invite_only" do
      serialized = serialized_score("invite_only")
      expect(serialized.reason_data).to be_nil
    end

    it "returns nil for email_spam" do
      serialized = serialized_score("email_spam")
      expect(serialized.reason_data).to be_nil
    end

    it "returns nil for suspect_user" do
      serialized = serialized_score("suspect_user")
      expect(serialized.reason_data).to be_nil
    end

    it "returns nil for contains_media" do
      serialized = serialized_score("contains_media")
      expect(serialized.reason_data).to be_nil
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
