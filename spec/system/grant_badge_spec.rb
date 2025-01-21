# frozen_string_literal: true

describe "Granting Badges", type: :system do
  before { SiteSetting.enable_badges = true }

  context "when in topic" do
    fab!(:post) { Fabricate(:post, raw: "This is some post to bookmark") }
    fab!(:admin)
    fab!(:badge_to_grant) { Fabricate(:manually_grantable_badge) }
    fab!(:other_badge) { Fabricate(:manually_grantable_badge) }
    let(:user) { post.user }
    let(:topic) { post.topic }
    let(:topic_page) { PageObjects::Pages::Topic.new }
    let(:badge_modal) { PageObjects::Modals::Badge.new }

    before { sign_in(admin) }

    def visit_topic_and_open_badge_modal(post)
      topic_page.visit_topic(topic)
      topic_page.expand_post_actions(post)
      topic_page.expand_post_admin_actions(post)
      topic_page.click_post_admin_action_button(post, :grant_badge)
    end

    it "grants badge with the correct badge reason which links the right post" do
      visit_topic_and_open_badge_modal(post)
      badge_modal.select_badge(badge_to_grant.name)
      badge_modal.grant

      expect(badge_modal).to have_success_flash_visible
      granted_badge = UserBadge.last
      expect(granted_badge.badge_id).to eq badge_to_grant.id
      expect(granted_badge.post_id).to eq post.id
    end
  end

  context "when granting a badge that shows in the post header" do
    fab!(:user)
    fab!(:post) { Fabricate(:post, user: user) }

    let(:topic_page) { PageObjects::Pages::Topic.new }

    fab!(:badge) do
      Fabricate(
        :manually_grantable_badge,
        name: "SomeBadge",
        listable: true,
        show_posts: true,
        show_in_post_header: true,
      )
    end
    fab!(:user_badge) do
      UserBadge.create!(
        badge_id: badge.id,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
        post_id: post.id,
      )
    end

    it "shows badge in post header" do
      topic_page.visit_topic(post.topic)
      expect(topic_page.post_by_number(post).find(".user-badge-buttons")).to have_css(
        ".user-badge-button-somebadge",
      )
    end

    it "doesn't show badge in post header when `show_badges_in_post_header` site setting is disabled" do
      SiteSetting.show_badges_in_post_header = false
      topic_page.visit_topic(post.topic)
      expect(topic_page.post_by_number(post)).to_not have_css(".user-badge-buttons")
    end
  end
end
