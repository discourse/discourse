# frozen_string_literal: true

RSpec.describe ReviewableScoreSerializer do
  fab!(:reviewable) { Fabricate(:reviewable_flagged_post) }
  fab!(:admin) { Fabricate(:admin) }

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
      ]

      reasons.each do |r|
        it "addd a link to a site setting for the #{r} reason" do
          serialized = serialized_score(r)
          setting_name = described_class::REASONS_AND_SETTINGS[r.to_sym]
          link_url =
            "#{Discourse.base_url}/admin/site_settings/category/all_results?filter=#{setting_name}"
          link = "<a href=\"#{link_url}\">#{setting_name.gsub("_", " ")}</a>"

          expect(serialized.reason).to include(link)
        end
      end
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
