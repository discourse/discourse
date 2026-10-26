# frozen_string_literal: true

describe "Admin Permalinks Page" do
  fab!(:admin)
  fab!(:post)

  let(:admin_permalinks_page) { PageObjects::Pages::AdminPermalinks.new }
  let(:admin_permalink_form_page) { PageObjects::Pages::AdminPermalinkForm.new }

  before { sign_in(admin) }

  it "lets the admin manage a permalink and open permalink settings" do
    admin_permalinks_page.visit
    aggregate_failures "empty permalink list" do
      expect(admin_permalinks_page).to have_no_filter
    end

    admin_permalinks_page.click_add_permalink
    admin_permalink_form_page
      .fill_in_url("test")
      .select_permalink_type("category")
      .fill_in_category("1")
      .click_save
    aggregate_failures "created permalink" do
      expect(admin_permalinks_page).to have_permalinks("test")
      expect(admin_permalinks_page).to have_filter
    end

    admin_permalinks_page.filter("no results")
    aggregate_failures "unmatched permalink" do
      expect(admin_permalinks_page).to have_no_results
      expect(admin_permalinks_page).to have_filter
    end

    admin_permalinks_page.filter("")

    admin_permalinks_page.click_edit_permalink("test")
    admin_permalink_form_page.fill_in_url("test2").click_save
    aggregate_failures "renamed permalink" do
      expect(admin_permalinks_page).to have_permalinks("test2")
    end

    admin_permalinks_page.click_delete_permalink("test2")

    aggregate_failures "deleted permalink" do
      expect(admin_permalinks_page).to have_no_permalinks
    end

    admin_permalinks_page.click_tab("settings")

    aggregate_failures "permalink settings" do
      expect(admin_permalinks_page).to have_active_tab("settings")
    end
  end
end
