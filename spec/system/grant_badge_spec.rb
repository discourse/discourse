# frozen_string_literal: true

describe "Granting Badges", type: :system do
  before { SiteSetting.enable_badges = true }

  context "when in topic" do
    fab!(:post) { Fabricate(:post, raw: "This is some post to bookmark") }
    fab!(:admin) { Fabricate(:admin) }
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
end
