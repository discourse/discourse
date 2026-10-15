# frozen_string_literal: true

describe "Review filters" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:regular_user, :user)
  fab!(:flagged_post_1, :reviewable_flagged_post)
  fab!(:flagged_post_2, :reviewable_flagged_post)
  fab!(:flagged_post_3, :reviewable_flagged_post)

  let(:review_index_page) { PageObjects::Pages::ReviewIndex.new }

  before { sign_in(admin) }

  describe "claimed by filter" do
    context "when reviewable claiming is enabled" do
      before { SiteSetting.reviewable_claiming = "optional" }

      it "shows only reviewables claimed by the selected user via URL parameter" do
        ReviewableClaimedTopic.create!(user: moderator, topic: flagged_post_1.topic)

        browser_page
          .goto("/review?claimed_by=#{moderator.username}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(
          browser_root.locator(".review-item").filter(visible: true),
        ).to PlaywrightMatchers.have_count(1)
        expect(
          browser_root.locator(".review-item[data-reviewable-id='#{flagged_post_1.id}']").filter(
            visible: true,
          ),
        ).not_to PlaywrightMatchers.have_count(0)
      end

      it "shows no reviewables when filtering by a user who has not claimed any" do
        ReviewableClaimedTopic.create!(user_id: moderator.id, topic_id: flagged_post_1.topic_id)

        browser_page
          .goto("/review?claimed_by=#{admin.username}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(
          browser_root.locator(".reviewable-item").filter(visible: true),
        ).to PlaywrightMatchers.have_count(0)
      end
    end

    context "when reviewable claiming is disabled" do
      before { SiteSetting.reviewable_claiming = "disabled" }

      it "does not show the claimed by filter" do
        browser_page.goto("/review").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        review_index_page.expand_filters
        expect(browser_content).not_to PlaywrightMatchers.contain_text(
          browser_text_pattern("Flag claimed by"),
          useInnerText: true,
        )
      end
    end
  end

  context "when category group moderation is enabled" do
    fab!(:category)
    fab!(:group)
    fab!(:category_group_user, :user)

    before do
      SiteSetting.enable_category_group_moderation = true
      SiteSetting.reviewable_claiming = "optional"
      group.add(category_group_user)
      CategoryModerationGroup.create!(category: category, group: group)
      ReviewableClaimedTopic.create!(user: category_group_user, topic: flagged_post_1.topic)
    end

    it "allows to filter review claimed by category group moderators" do
      browser_page.goto("/review").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(
        browser_root.locator(".review-item").filter(visible: true),
      ).to PlaywrightMatchers.have_count(3)

      review_index_page.expand_filters

      review_index_page.claimed_by_select.expand
      review_index_page.claimed_by_select.search(category_group_user.username)
      review_index_page.claimed_by_select.select_row_by_value(category_group_user.username)

      review_index_page.submit_filters

      expect(
        browser_root.locator(".review-item").filter(visible: true),
      ).to PlaywrightMatchers.have_count(1)
      expect(
        browser_root.locator(".review-item[data-reviewable-id='#{flagged_post_1.id}']").filter(
          visible: true,
        ),
      ).not_to PlaywrightMatchers.have_count(0)
    end
  end
end
