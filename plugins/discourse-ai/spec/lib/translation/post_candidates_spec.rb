# frozen_string_literal: true

describe DiscourseAi::Translation::PostCandidates do
  describe ".get" do
    it "does not return bot posts" do
      post = Fabricate(:post, user: Discourse.system_user)

      expect(DiscourseAi::Translation::PostCandidates.get).not_to include(post)
    end

    it "does not return posts older than ai_translation_backfill_max_age_days" do
      post =
        Fabricate(
          :post,
          created_at: SiteSetting.ai_translation_backfill_max_age_days.days.ago - 1.day,
        )

      expect(DiscourseAi::Translation::PostCandidates.get).not_to include(post)
    end

    it "does not return deleted posts" do
      post = Fabricate(:post, deleted_at: Time.now)

      expect(DiscourseAi::Translation::PostCandidates.get).not_to include(post)
    end

    describe "SiteSetting.ai_translation_backfill_limit_to_public_content" do
      fab!(:pm_post) { Fabricate(:post, topic: Fabricate(:private_message_topic)) }
      fab!(:group_pm_post) do
        Fabricate(
          :post,
          topic: Fabricate(:private_message_topic, allowed_groups: [Fabricate(:group)]),
        )
      end
      fab!(:public_post) do
        Fabricate(
          :post,
          topic: Fabricate(:topic, category: Fabricate(:category, read_restricted: false)),
        )
      end

      it "excludes PMs and only includes posts from public categories" do
        SiteSetting.ai_translation_backfill_limit_to_public_content = true

        posts = DiscourseAi::Translation::PostCandidates.get
        expect(posts).not_to include(pm_post)
        expect(posts).not_to include(group_pm_post)
        expect(posts).to include(public_post)
      end

      it "includes all regular posts and group PMs but not personal PMs" do
        SiteSetting.ai_translation_backfill_limit_to_public_content = false

        posts = DiscourseAi::Translation::PostCandidates.get
        expect(posts).not_to include(pm_post)
        expect(posts).to include(group_pm_post)
        expect(posts).to include(public_post)
      end
    end
  end

  describe ".get_completion_all_locales" do
    before do
      SiteSetting.content_localization_supported_locales = "en_GB|pt|es"
      SiteSetting.ai_translation_backfill_max_age_days = 30
      SiteSetting.ai_translation_backfill_limit_to_public_content = false
    end

    it "returns empty state when no posts exist" do
      Post.delete_all

      result = DiscourseAi::Translation::PostCandidates.get_completion_all_locales
      expect(result).to be_a(Hash)
      expect(result[:translation_progress].length).to eq(3)
      expect(result[:translation_progress]).to all(include(done: 0, total: 0))
      expect(result[:total]).to eq(0)
      expect(result[:posts_with_detected_locale]).to eq(0)
    end

    it "returns progress grouped by base locale (of en_GB) and correct totals" do
      post1 = Fabricate(:post, locale: "en_GB")
      post2 = Fabricate(:post, locale: "fr")
      post3 = Fabricate(:post, locale: "es")
      post_without_locale = Fabricate(:post, locale: nil) # not eligible for translation

      # add an en_GB localization to a non-en base post
      PostLocalization.create!(
        post: post2,
        locale: "en",
        raw: "Translated to English",
        cooked: "<p>Translated to English</p>",
        post_version: post2.version,
        localizer_user_id: Discourse.system_user.id,
      )

      result = DiscourseAi::Translation::PostCandidates.completion_all_locales
      expect(result).to be_a(Hash)
      expect(result[:translation_progress].length).to eq(3)
      expect(result[:total]).to eq(4) # all eligible posts (including one without locale)
      expect(result[:posts_with_detected_locale]).to eq(3) # only posts with locale

      progress = result[:translation_progress]
      expect(progress).to all(include(:locale, :done, :total))

      expect(progress.first[:locale]).to eq("en_GB")

      en_entry = progress.find { |r| r[:locale] == "en_GB" }
      expect(en_entry).to be_present
      # total is non-English posts (post2 + post3)
      expect(en_entry[:done]).to eq(1)
      expect(en_entry[:total]).to eq(2)

      pt_entry = progress.find { |r| r[:locale] == "pt" }
      expect(pt_entry).to be_present
      expect(pt_entry[:done]).to eq(0)
      expect(pt_entry[:total]).to eq(3)
      es_entry = progress.find { |r| r[:locale] == "es" }
      expect(es_entry).to be_present
      expect(es_entry[:done]).to eq(0)
      expect(es_entry[:total]).to eq(2)
      fr_entry = progress.find { |r| r[:locale] == "fr" }
      expect(fr_entry).to be_nil
    end
  end
end
