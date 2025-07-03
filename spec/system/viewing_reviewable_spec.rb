# frozen_string_literal: true

describe "Viewing reviewable item", type: :system do
  fab!(:admin)
  fab!(:group)
  fab!(:reviewable_flagged_post)

  before { sign_in(admin) }

  context "when user is not part of the groups list of the `reviewable_ui_refresh` site setting" do
    before { SiteSetting.reviewable_ui_refresh = "" }

    it "shows the old reviewable UI" do
      visit "/review/#{reviewable_flagged_post.id}"

      expect(page).to have_selector(".reviewable-item ")
    end
  end

  context "when user is part of the groups list of the `reviewable_ui_refresh` site setting" do
    before do
      SiteSetting.reviewable_ui_refresh = group.name
      group.add(admin)
    end

    it "shows the new reviewable UI" do
      visit "/review/#{reviewable_flagged_post.id}"

      expect(page).to have_selector(".review-container")
    end
  end
end
