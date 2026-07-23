# frozen_string_literal: true

describe DiscourseAi::Translation::PostCandidates do
  before do
    SiteSetting.ai_translation_category_scope = "all"
    SiteSetting.ai_translation_categories = ""
  end

  describe ".get" do
    it "does not return bot posts" do
      post = Fabricate(:post, user: Discourse.system_user)

      expect(DiscourseAi::Translation::PostCandidates.get).not_to include(post)
    end

    describe "SiteSetting.ai_translation_include_bot_content" do
      it "includes bot posts when enabled" do
        SiteSetting.ai_translation_include_bot_content = true
        bot_post = Fabricate(:post, user: Discourse.system_user)
        regular_post = Fabricate(:post)

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

      expect(DiscourseAi::Translation::PostCandidates.get).not_to include(post)
    end

    it "does not return deleted posts" do
      post = Fabricate(:post, deleted_at: Time.now)

      expect(DiscourseAi::Translation::PostCandidates.get).not_to include(post)
    end

    it "does not return posts longer than ai_translation_max_post_length" do
      SiteSetting.ai_translation_max_post_length = 100
      short_post = Fabricate(:post, raw: "This is a short post that fits within the limit.")
      long_post = Fabricate(:post, raw: "a" * 50 + " This is a long post. " + "b" * 50)

      posts = DiscourseAi::Translation::PostCandidates.get
      expect(posts).to include(short_post)
      expect(posts).not_to include(long_post)
    end

    describe "category and PM filtering" do
      fab!(:target_category, :category)
      fab!(:non_target_category, :category)
      fab!(:group)
      fab!(:pm_post) { Fabricate(:post, topic: Fabricate(:private_message_topic)) }
      fab!(:group_pm_post) do
        Fabricate(:post, topic: Fabricate(:private_message_topic, allowed_groups: [group]))
      end
      fab!(:target_post) { Fabricate(:post, topic: Fabricate(:topic, category: target_category)) }
      fab!(:non_target_post) do
        Fabricate(:post, topic: Fabricate(:topic, category: non_target_category))
      end

      it "includes posts from private categories by default" do
        private_category = Fabricate(:private_category, group:)
        private_post = Fabricate(:post, topic: Fabricate(:topic, category: private_category))
        SiteSetting.ai_translation_personal_messages = "none"

        expect(DiscourseAi::Translation::PostCandidates.get).to include(private_post)
      end

      it "includes only posts from public categories when configured" do
        private_category = Fabricate(:private_category, group:)
        private_post = Fabricate(:post, topic: Fabricate(:topic, category: private_category))
        SiteSetting.ai_translation_category_scope = "public"
        SiteSetting.ai_translation_personal_messages = "none"

        posts = DiscourseAi::Translation::PostCandidates.get
        expect(posts).to include(target_post)
        expect(posts).not_to include(private_post)
      end

      it "includes posts from selected categories and subcategories" do
        subcategory = Fabricate(:category, parent_category: target_category)
        subcategory_post = Fabricate(:post, topic: Fabricate(:topic, category: subcategory))
        SiteSetting.ai_translation_category_scope = "include"
        SiteSetting.ai_translation_categories = target_category.id.to_s
        SiteSetting.ai_translation_personal_messages = "none"

        posts = DiscourseAi::Translation::PostCandidates.get
        expect(posts).to include(target_post, subcategory_post)
        expect(posts).not_to include(non_target_post)
      end

      it "excludes selected categories and subcategories" do
        subcategory = Fabricate(:category, parent_category: non_target_category)
        subcategory_post = Fabricate(:post, topic: Fabricate(:topic, category: subcategory))
        SiteSetting.ai_translation_category_scope = "exclude"
        SiteSetting.ai_translation_categories = non_target_category.id.to_s
        SiteSetting.ai_translation_personal_messages = "none"

        posts = DiscourseAi::Translation::PostCandidates.get
        expect(posts).to include(target_post)
        expect(posts).not_to include(non_target_post, subcategory_post, pm_post, group_pm_post)
      end

      it "includes group PMs but not personal PMs when pm_translation_scope is group" do
        SiteSetting.ai_translation_category_scope = "exclude"
        SiteSetting.ai_translation_categories = non_target_category.id.to_s
        SiteSetting.ai_translation_personal_messages = "group"

        posts = DiscourseAi::Translation::PostCandidates.get
        expect(posts).to include(target_post)
        expect(posts).not_to include(pm_post)
        expect(posts).to include(group_pm_post)
      end

      it "includes all PMs when pm_translation_scope is all" do
        SiteSetting.ai_translation_category_scope = "exclude"
        SiteSetting.ai_translation_categories = non_target_category.id.to_s
        SiteSetting.ai_translation_personal_messages = "all"

        posts = DiscourseAi::Translation::PostCandidates.get
        expect(posts).to include(target_post)
        expect(posts).to include(pm_post)
        expect(posts).to include(group_pm_post)
      end
    end
  end

  describe ".needs_localization" do
    fab!(:target_category, :category)

    before do
      SiteSetting.ai_translation_backfill_max_age_days = 100
      SiteSetting.content_localization_supported_locales = "en|ja|de"
      SiteSetting.ai_translation_category_scope = "all"
      SiteSetting.ai_translation_categories = ""
      SiteSetting.ai_translation_personal_messages = "none"
    end

    it "returns [post_id, target_locale] pairs for posts needing localization" do
      post = Fabricate(:post, locale: "es", topic: Fabricate(:topic, category: target_category))

      pairs = described_class.needs_localization(limit: 10)
      expect(pairs).to include([post.id, "en"])
      expect(pairs).to include([post.id, "ja"])
      expect(pairs).to include([post.id, "de"])
    end

    it "excludes posts without a detected locale" do
      Fabricate(:post, locale: nil, topic: Fabricate(:topic, category: target_category))

      pairs = described_class.needs_localization(limit: 10)
      expect(pairs).to be_empty
    end

    it "excludes fully translated posts" do
      post = Fabricate(:post, locale: "es", topic: Fabricate(:topic, category: target_category))
      Fabricate(:post_localization, post: post, locale: "en")
      Fabricate(:post_localization, post: post, locale: "ja")
      Fabricate(:post_localization, post: post, locale: "de")

      pairs = described_class.needs_localization(limit: 10)
      post_ids = pairs.map(&:first)
      expect(post_ids).not_to include(post.id)
    end

    it "returns only missing locale pairs for partially translated posts" do
      post = Fabricate(:post, locale: "es", topic: Fabricate(:topic, category: target_category))
      Fabricate(:post_localization, post: post, locale: "en")

      pairs = described_class.needs_localization(limit: 10)
      expect(pairs).not_to include([post.id, "en"])
      expect(pairs).to include([post.id, "ja"])
      expect(pairs).to include([post.id, "de"])
    end

    it "excludes posts whose locale matches all target base locales" do
      SiteSetting.content_localization_supported_locales = "en"
      post = Fabricate(:post, locale: "en", topic: Fabricate(:topic, category: target_category))

      pairs = described_class.needs_localization(limit: 10)
      post_ids = pairs.map(&:first)
      expect(post_ids).not_to include(post.id)
    end

    it "handles base-locale deduplication (ja_JP localization covers ja target)" do
      post = Fabricate(:post, locale: "es", topic: Fabricate(:topic, category: target_category))
      Fabricate(:post_localization, post: post, locale: "en")
      Fabricate(:post_localization, post: post, locale: "ja_JP")
      Fabricate(:post_localization, post: post, locale: "de_DE")

      pairs = described_class.needs_localization(limit: 10)
      post_ids = pairs.map(&:first)
      expect(post_ids).not_to include(post.id)
    end

    it "respects the limit parameter" do
      3.times do
        Fabricate(:post, locale: "es", topic: Fabricate(:topic, category: target_category))
      end

      pairs = described_class.needs_localization(limit: 2)
      expect(pairs.size).to eq(2)
    end

    it "returns empty when no locales are configured" do
      SiteSetting.content_localization_supported_locales = ""

      pairs = described_class.needs_localization(limit: 10)
      expect(pairs).to be_empty
    end
  end

  describe ".progress_summary" do
    fab!(:target_category, :category)

    before do
      SiteSetting.content_localization_supported_locales = "en_GB|fr"
      SiteSetting.ai_translation_backfill_max_age_days = 30
      SiteSetting.ai_translation_category_scope = "include_strict"
      SiteSetting.ai_translation_categories = target_category.id.to_s
      SiteSetting.ai_translation_personal_messages = "none"
    end

    it "counts eligible, fully translated, and undetected posts" do
      fully_translated_post =
        Fabricate(:post, locale: "en_US", topic: Fabricate(:topic, category: target_category))
      Fabricate(:post_localization, post: fully_translated_post, locale: "fr")
      Fabricate(:post, locale: "en_US", topic: Fabricate(:topic, category: target_category))
      Fabricate(:post, locale: nil, topic: Fabricate(:topic, category: target_category))

      expect(described_class.progress_summary).to eq(
        {
          target_type: "post",
          total_count: 3,
          translated_count: 1,
          needs_language_detection_count: 1,
        },
      )
    end
  end
end
