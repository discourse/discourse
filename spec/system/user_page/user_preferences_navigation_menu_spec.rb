# frozen_string_literal: true

describe "User preferences | Navigation Menu", type: :system do
  fab!(:user)
  let(:user_preferences_navigation_menu_page) do
    PageObjects::Pages::UserPreferencesNavigationMenu.new
  end
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }

  before { sign_in(user) }

  describe "sidebar_link_to_filtered_list preference" do
    it "correctly updates the user_option when toggling the checkbox" do
      user_preferences_navigation_menu_page.visit(user)

      expect(form.field("sidebar_link_to_filtered_list")).to be_unchecked
      expect(user.user_option.sidebar_link_to_filtered_list).to eq(false)

      form.field("sidebar_link_to_filtered_list").toggle
      form.submit
      expect(page).to have_css(".saved")

      expect(user.user_option.reload.sidebar_link_to_filtered_list).to eq(true)

      page.refresh

      expect(form.field("sidebar_link_to_filtered_list")).to be_checked

      form.field("sidebar_link_to_filtered_list").toggle
      form.submit
      expect(page).to have_css(".saved")

      expect(user.user_option.reload.sidebar_link_to_filtered_list).to eq(false)

      page.refresh

      expect(form.field("sidebar_link_to_filtered_list")).to be_unchecked
    end
  end

  describe "sidebar_show_count_of_new_items preference" do
    it "correctly updates the user_option when toggling the checkbox" do
      user_preferences_navigation_menu_page.visit(user)

      expect(form.field("sidebar_show_count_of_new_items")).to be_unchecked
      expect(user.user_option.sidebar_show_count_of_new_items).to eq(false)

      form.field("sidebar_show_count_of_new_items").toggle
      form.submit
      expect(page).to have_css(".saved")

      expect(user.user_option.reload.sidebar_show_count_of_new_items).to eq(true)

      page.refresh

      expect(form.field("sidebar_show_count_of_new_items")).to be_checked

      form.field("sidebar_show_count_of_new_items").toggle
      form.submit
      expect(page).to have_css(".saved")

      expect(user.user_option.reload.sidebar_show_count_of_new_items).to eq(false)

      page.refresh

      expect(form.field("sidebar_show_count_of_new_items")).to be_unchecked
    end
  end
end
