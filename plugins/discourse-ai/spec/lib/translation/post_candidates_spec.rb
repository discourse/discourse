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
    before { SiteSetting.content_localization_supported_locales = "en_GB|pt|es" }

    it "returns empty state when no posts exist" do
      Post.delete_all

      result = DiscourseAi::Translation::PostCandidates.get_completion_all_locales
      expect(result).to eq(
        [
          { done: 0, locale: "en_GB", total: 0 },
          { done: 0, locale: "pt", total: 0 },
          { done: 0, locale: "es", total: 0 },
        ],
      )
    end

    it "returns progress grouped by base locale (of en_GB) and correct totals" do
      post1 = Fabricate(:post, locale: "en_GB")
      post2 = Fabricate(:post, locale: "fr")
      Fabricate(:post, locale: "es")
      Fabricate(:post, locale: nil) # not eligible

      # add an en_GB localization to a non-en base post
      Fabricate(:post_localization, post: post2, locale: "en")

      result = DiscourseAi::Translation::PostCandidates.completion_all_locales
      expect(result.length).to eq(3)

      expect(result).to all(include(:locale, :done, :total))

      en_entry = result.find { |r| r[:locale] == "en_GB" }
      expect(en_entry).to be_present
      # post1 (en_GB base=en) + post2 (localization en_GB base=en)
      expect(en_entry[:done]).to eq(2)
      expect(en_entry[:total]).to eq(3)

      pt_entry = result.find { |r| r[:locale] == "pt" }
      expect(pt_entry).to be_present
      expect(pt_entry[:done]).to eq(0)
      expect(pt_entry[:total]).to eq(3)
      es_entry = result.find { |r| r[:locale] == "es" }
      expect(es_entry).to be_present
      expect(es_entry[:done]).to eq(1)
      expect(es_entry[:total]).to eq(3)
      fr_entry = result.find { |r| r[:locale] == "fr" }
      expect(fr_entry).to be_nil
    end
  end
end
