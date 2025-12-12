# frozen_string_literal: true

describe "Review filters", type: :system do
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

        visit("/review?claimed_by=#{moderator.username}")

        expect(page).to have_css(".reviewable-item", count: 1)
        expect(page).to have_css(".reviewable-item[data-reviewable-id='#{flagged_post_1.id}']")
      end

      it "shows no reviewables when filtering by a user who has not claimed any" do
        ReviewableClaimedTopic.create!(user_id: moderator.id, topic_id: flagged_post_1.topic_id)

        visit("/review?claimed_by=#{admin.username}")

        expect(page).to have_no_css(".reviewable-item")
      end
    end

    context "when reviewable claiming is disabled" do
      before { SiteSetting.reviewable_claiming = "disabled" }

      it "does not show the claimed by filter" do
        visit("/review")
        review_index_page.expand_filters
        expect(page).to have_no_text("Flag claimed by")
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
      visit("/review")
      expect(page).to have_css(".reviewable-item", count: 3)

      review_index_page.expand_filters

      review_index_page.claimed_by_select.expand
      review_index_page.claimed_by_select.search(category_group_user.username)
      review_index_page.claimed_by_select.select_row_by_value(category_group_user.username)

      review_index_page.submit_filters

      expect(page).to have_css(".reviewable-item", count: 1)
      expect(page).to have_css(".reviewable-item[data-reviewable-id='#{flagged_post_1.id}']")
    end
  end
end
