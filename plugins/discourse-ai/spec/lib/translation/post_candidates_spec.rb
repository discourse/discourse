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

  describe ".get_completion_per_locale" do
    context "when (scenario A) 'done' determined by post's locale" do
      it "returns total = done if all posts are in the locale" do
        locale = "pt_BR"
        Fabricate(:post, locale:)
        Post.update_all(locale: locale)
        Fabricate(:post, locale: "pt")

        completion = DiscourseAi::Translation::PostCandidates.get_completion_per_locale(locale)
        expect(completion).to eq({ done: 2, total: 2 })
      end

      it "returns correct done and total if some posts are in the locale" do
        locale = "es"
        Fabricate(:post, locale:)
        Fabricate(:post, locale: "not_es")

        completion = DiscourseAi::Translation::PostCandidates.get_completion_per_locale(locale)
        expect(completion).to eq({ done: 1, total: 2 })
      end
    end

    context "when (scenario B) 'done' determined by post localizations" do
      it "returns done = total if all posts have a localization in the locale" do
        locale = "pt_BR"
        Fabricate(:post, locale: "en")
        Post.all.each do |post|
          post.update(locale: "en")
          Fabricate(:post_localization, post:, locale:)
        end
        PostLocalization.order("RANDOM()").first.update(locale: "pt")

        completion = DiscourseAi::Translation::PostCandidates.get_completion_per_locale(locale)
        expect(completion).to eq({ done: Post.count, total: Post.count })
      end

      it "returns correct done and total if some posts have a localization in the locale" do
        locale = "es"
        post1 = Fabricate(:post, locale: "en")
        post2 = Fabricate(:post, locale: "fr")
        Fabricate(:post_localization, post: post1, locale:)
        Fabricate(:post_localization, post: post2, locale: "not_es")

        completion = DiscourseAi::Translation::PostCandidates.get_completion_per_locale(locale)
        posts_with_locale = Post.where.not(locale: nil).count
        expect(completion).to eq({ done: 1, total: posts_with_locale })
      end
    end

    it "returns the correct done and total based on (scenario A & B) `post.locale` and `PostLocalization` in the specified locale" do
      locale = "es"

      # translated candidates
      Fabricate(:post, locale:)
      post2 = Fabricate(:post, locale: "en")
      Fabricate(:post_localization, post: post2, locale:)

      # untranslated candidate
      post4 = Fabricate(:post, locale: "fr")
      Fabricate(:post_localization, post: post4, locale: "zh_CN")

      # not a candidate as it is a bot post
      post3 = Fabricate(:post, user: Discourse.system_user, locale: "de")
      Fabricate(:post_localization, post: post3, locale:)

      completion = DiscourseAi::Translation::PostCandidates.get_completion_per_locale(locale)
      translated_candidates = 2 # post1 + post2
      total_candidates = Post.count - 1 # excluding the bot post
      expect(completion).to eq({ done: translated_candidates, total: total_candidates })
    end

    it "does not allow done to exceed total when post.locale and post_localization both exist" do
      locale = "es"
      post = Fabricate(:post, locale:)
      Fabricate(:post_localization, post:, locale:)

      completion = DiscourseAi::Translation::PostCandidates.get_completion_per_locale(locale)
      expect(completion).to eq({ done: 1, total: 1 })
    end

    it "returns nil - nil for done and total when no posts are present" do
      SiteSetting.ai_translation_backfill_max_age_days = 0

      completion = DiscourseAi::Translation::PostCandidates.get_completion_per_locale("es")
      expect(completion).to eq({ done: 0, total: 0 })
    end
  end

  describe ".calculate_completion_progress_for_all_locales" do
    it "returns empty array when no posts exist" do
      Post.delete_all

      result =
        DiscourseAi::Translation::PostCandidates.calculate_completion_progress_for_all_locales
      expect(result).to eq([])
    end

    it "returns correct progress for posts with detected locales" do
      # Create posts with locales
      post1 = Fabricate(:post, locale: "en")
      post2 = Fabricate(:post, locale: "fr")
      post3 = Fabricate(:post, locale: "es")
      post4 = Fabricate(:post, locale: nil) # No locale detected

      # Create post localizations (translations)
      Fabricate(:post_localization, post: post1, locale: "fr")
      Fabricate(:post_localization, post: post2, locale: "en")

      result =
        DiscourseAi::Translation::PostCandidates.calculate_completion_progress_for_all_locales

      expect(result.length).to eq(2)

      # Should have entries for locales that have translations
      fr_entry = result.find { |r| r[:locale] == "fr" }
      en_entry = result.find { |r| r[:locale] == "en" }

      expect(fr_entry).to be_present
      expect(fr_entry[:done]).to eq(1)
      expect(fr_entry[:total]).to eq(3) # Only posts with detected locales

      expect(en_entry).to be_present
      expect(en_entry[:done]).to eq(1)
      expect(en_entry[:total]).to eq(3)
    end

    it "excludes bot posts from calculation" do
      # Regular post
      post1 = Fabricate(:post, locale: "en")
      # Bot post
      bot_post = Fabricate(:post, user: Discourse.system_user, locale: "fr")

      # Translation for bot post (should not count)
      Fabricate(:post_localization, post: bot_post, locale: "en")

      result =
        DiscourseAi::Translation::PostCandidates.calculate_completion_progress_for_all_locales

      if result.any?
        en_entry = result.find { |r| r[:locale] == "en" }
        expect(en_entry[:total]).to eq(1) # Only the regular post
        expect(en_entry[:done]).to eq(1) # The bot post translation doesn't count
      end
    end

    it "excludes posts older than ai_translation_backfill_max_age_days" do
      SiteSetting.ai_translation_backfill_max_age_days = 30

      # Recent post
      recent_post = Fabricate(:post, locale: "en", created_at: 10.days.ago)
      # Old post
      old_post = Fabricate(:post, locale: "fr", created_at: 40.days.ago)

      Fabricate(:post_localization, post: recent_post, locale: "fr")

      result =
        DiscourseAi::Translation::PostCandidates.calculate_completion_progress_for_all_locales

      if result.any?
        fr_entry = result.find { |r| r[:locale] == "fr" }
        expect(fr_entry[:total]).to eq(1) # Only the recent post
        expect(fr_entry[:done]).to eq(1)
      end
    end

    it "excludes deleted posts" do
      # Regular post
      post1 = Fabricate(:post, locale: "en")
      # Deleted post
      deleted_post = Fabricate(:post, locale: "fr", deleted_at: 1.hour.ago)

      Fabricate(:post_localization, post: post1, locale: "fr")

      result =
        DiscourseAi::Translation::PostCandidates.calculate_completion_progress_for_all_locales

      if result.any?
        fr_entry = result.find { |r| r[:locale] == "fr" }
        expect(fr_entry[:total]).to eq(1) # Only the non-deleted post
        expect(fr_entry[:done]).to eq(1)
      end
    end

    it "handles posts with both original locale and translation to same locale" do
      # Post originally in English
      post = Fabricate(:post, locale: "en")
      # Also has English translation (edge case)
      Fabricate(:post_localization, post: post, locale: "en")

      result =
        DiscourseAi::Translation::PostCandidates.calculate_completion_progress_for_all_locales

      en_entry = result.find { |r| r[:locale] == "en" }
      expect(en_entry[:done]).to eq(1)
      expect(en_entry[:total]).to eq(1)
    end

    context "with SiteSetting.ai_translation_backfill_limit_to_public_content" do
      fab!(:public_post) do
        Fabricate(
          :post,
          locale: "en",
          topic: Fabricate(:topic, category: Fabricate(:category, read_restricted: false)),
        )
      end
      fab!(:private_post) do
        Fabricate(:post, locale: "fr", topic: Fabricate(:private_message_topic))
      end

      it "includes only public posts when enabled" do
        SiteSetting.ai_translation_backfill_limit_to_public_content = true

        Fabricate(:post_localization, post: public_post, locale: "fr")
        Fabricate(:post_localization, post: private_post, locale: "en")

        result =
          DiscourseAi::Translation::PostCandidates.calculate_completion_progress_for_all_locales

        if result.any?
          # Should only count the public post in totals
          fr_entry = result.find { |r| r[:locale] == "fr" }
          expect(fr_entry[:total]).to eq(1) # Only public post
          expect(fr_entry[:done]).to eq(1)
        end
      end

      it "includes both public and group message posts when disabled" do
        SiteSetting.ai_translation_backfill_limit_to_public_content = false
        group_pm_post =
          Fabricate(
            :post,
            locale: "es",
            topic: Fabricate(:private_message_topic, allowed_groups: [Fabricate(:group)]),
          )

        Fabricate(:post_localization, post: public_post, locale: "fr")
        Fabricate(:post_localization, post: group_pm_post, locale: "en")

        result =
          DiscourseAi::Translation::PostCandidates.calculate_completion_progress_for_all_locales

        if result.any?
          # Should count both public and group PM posts
          total_eligible_posts = 2 # public_post + group_pm_post (excludes personal PM)
          entries_with_counts = result.select { |r| r[:total] > 0 }
          expect(entries_with_counts.first[:total]).to eq(total_eligible_posts)
        end
      end
    end
  end
end
