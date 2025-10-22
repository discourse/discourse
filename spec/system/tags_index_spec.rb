# frozen_string_literal: true

describe "Tags index page", type: :system do
  fab!(:admin)
  fab!(:user)

  context "when visiting as a staff user" do
    it "shows the admin dropdown" do
      sign_in(admin)
      visit("/tags")

      expect(page).to have_css(".tags-admin-dropdown")
    end
  end

  context "when visiting as a regular user" do
    it "does not show the admin dropdown" do
      sign_in(user)
      visit("/tags")

      expect(page).to have_css(".tags-index")
      expect(page).to have_no_css(".tags-admin-dropdown")
    end
  end
end
