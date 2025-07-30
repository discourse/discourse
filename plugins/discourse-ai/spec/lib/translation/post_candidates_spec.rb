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
    context "when (scenario A) percentage determined by post's locale" do
      it "returns 100% completion if all posts are in the locale" do
        locale = "es"
        Fabricate(:post, locale:)
        Post.update_all(locale: locale)

        completion = DiscourseAi::Translation::PostCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1.0)
      end

      it "returns X% completion if some posts are in the locale" do
        locale = "es"
        Fabricate(:post, locale:)

        completion = DiscourseAi::Translation::PostCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1 / Post.count.to_f)
      end
    end

    context "when (scenario B) percentage determined by post localizations" do
      it "returns 100% completion if all posts have a localization in the locale" do
        locale = "es"
        Fabricate(:post)
        Post.all.each { |post| Fabricate(:post_localization, post:, locale:) }

        completion = DiscourseAi::Translation::PostCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1.0)
      end

      it "returns X% completion if some posts have a localization in the locale" do
        locale = "es"
        post = Fabricate(:post)
        Fabricate(:post_localization, post:, locale:)

        completion = DiscourseAi::Translation::PostCandidates.get_completion_per_locale(locale)
        expect(completion).to eq(1 / Post.count.to_f)
      end
    end

    it "returns the correct percentage based on (scenario A & B) `post.locale` and `PostLocalization` in the specified locale" do
      locale = "es"
      Fabricate(:post, locale:)
      post = Fabricate(:post)
      Fabricate(:post_localization, post:, locale:)

      completion = DiscourseAi::Translation::PostCandidates.get_completion_per_locale(locale)
      expect(completion).to eq(2 / Post.count.to_f)
    end
  end
end
