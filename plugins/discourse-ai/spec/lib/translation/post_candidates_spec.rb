# frozen_string_literal: true

describe DiscourseAi::Translation::PostCandidates do
  before { SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|") }

  describe ".get" do
    it "does not return bot posts" do
      post = Fabricate(:post, user: Discourse.system_user)
      SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

      expect(DiscourseAi::Translation::PostCandidates.get).not_to include(post)
    end

    describe "SiteSetting.ai_translation_include_bot_content" do
      it "includes bot posts when enabled" do
        SiteSetting.ai_translation_include_bot_content = true
        bot_post = Fabricate(:post, user: Discourse.system_user)
        regular_post = Fabricate(:post)
        SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

        posts = DiscourseAi::Translation::PostCandidates.get
        expect(posts).to include(bot_post)
        expect(posts).to include(regular_post)
      end
    end

    it "does not return posts older than ai_translation_backfill_max_age_days" do
      post =
        Fabricate(
          :post,
          created_at: SiteSetting.ai_translation_backfill_max_age_days.days.ago - 1.day,
        )
      SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

      expect(DiscourseAi::Translation::PostCandidates.get).not_to include(post)
    end

    it "does not return deleted posts" do
      post = Fabricate(:post, deleted_at: Time.now)
      SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

      expect(DiscourseAi::Translation::PostCandidates.get).not_to include(post)
    end

    it "does not return posts longer than ai_translation_max_post_length" do
      SiteSetting.ai_translation_max_post_length = 100
      short_post = Fabricate(:post, raw: "This is a short post that fits within the limit.")
      long_post = Fabricate(:post, raw: "a" * 50 + " This is a long post. " + "b" * 50)
      SiteSetting.ai_translation_target_categories = Category.pluck(:id).join("|")

      posts = DiscourseAi::Translation::PostCandidates.get
      expect(posts).to include(short_post)
      expect(posts).not_to include(long_post)
    end

    describe "category and PM filtering" do
      fab!(:target_category, :category)
      fab!(:non_target_category, :category)
      fab!(:pm_post) { Fabricate(:post, topic: Fabricate(:private_message_topic)) }
      fab!(:group_pm_post) do
        Fabricate(
          :post,
          topic: Fabricate(:private_message_topic, allowed_groups: [Fabricate(:group)]),
        )
      end
      fab!(:target_post) { Fabricate(:post, topic: Fabricate(:topic, category: target_category)) }
      fab!(:non_target_post) do
        Fabricate(:post, topic: Fabricate(:topic, category: non_target_category))
      end

      it "only includes posts from target categories" do
        SiteSetting.ai_translation_target_categories = target_category.id.to_s
        SiteSetting.ai_translation_personal_messages = "none"

        posts = DiscourseAi::Translation::PostCandidates.get
        expect(posts).to include(target_post)
        expect(posts).not_to include(non_target_post)
        expect(posts).not_to include(pm_post)
        expect(posts).not_to include(group_pm_post)
      end

      it "includes group PMs but not personal PMs when pm_translation_scope is group" do
        SiteSetting.ai_translation_target_categories = target_category.id.to_s
        SiteSetting.ai_translation_personal_messages = "group"

        posts = DiscourseAi::Translation::PostCandidates.get
        expect(posts).to include(target_post)
        expect(posts).not_to include(pm_post)
        expect(posts).to include(group_pm_post)
      end

      it "includes all PMs when pm_translation_scope is all" do
        SiteSetting.ai_translation_target_categories = target_category.id.to_s
        SiteSetting.ai_translation_personal_messages = "all"

        posts = DiscourseAi::Translation::PostCandidates.get
        expect(posts).to include(target_post)
        expect(posts).to include(pm_post)
        expect(posts).to include(group_pm_post)
      end
    end
  end

  describe ".get_completion_all_locales" do
    fab!(:target_category, :category)

    before do
      SiteSetting.content_localization_supported_locales = "en_GB|pt|es"
      SiteSetting.ai_translation_backfill_max_age_days = 30
      SiteSetting.ai_translation_target_categories = target_category.id.to_s
      SiteSetting.ai_translation_personal_messages = "group"
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
      post1 = Fabricate(:post, locale: "en_GB", topic: Fabricate(:topic, category: target_category))
      post2 = Fabricate(:post, locale: "fr", topic: Fabricate(:topic, category: target_category))
      post3 = Fabricate(:post, locale: "es", topic: Fabricate(:topic, category: target_category))
      post_without_locale =
        Fabricate(:post, locale: nil, topic: Fabricate(:topic, category: target_category))

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

    it "excludes posts longer than ai_translation_max_post_length from totals" do
      SiteSetting.ai_translation_max_post_length = 100
      short_post =
        Fabricate(
          :post,
          locale: "en_GB",
          raw: "This is a short post that fits.",
          topic: Fabricate(:topic, category: target_category),
        )
      long_post =
        Fabricate(
          :post,
          locale: "fr",
          raw: "a" * 50 + " This is a long post. " + "b" * 50,
          topic: Fabricate(:topic, category: target_category),
        )

      result = DiscourseAi::Translation::PostCandidates.get_completion_all_locales
      expect(result[:total]).to eq(1)
      expect(result[:posts_with_detected_locale]).to eq(1)
    end
  end
end
