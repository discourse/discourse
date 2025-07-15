# frozen_string_literal: true

describe "Category calendar", type: :system do
  fab!(:admin)
  fab!(:category)

  let(:category_page) { PageObjects::Pages::Category.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.events_calendar_categories = category.id.to_s
    sign_in(admin)
  end

  it "shows the calendar on the category page" do
    category_page.visit(category)

    expect(category_page).to have_selector("#category-events-calendar.fc")

    find(".nav-item_hot").click

    expect(page).to have_current_path("#{category.relative_url}/l/hot")
    expect(category_page).to have_selector("#category-events-calendar.fc")

    find(".nav-item_latest").click

    expect(page).to have_current_path("#{category.relative_url}/l/latest")
    expect(category_page).to have_selector("#category-events-calendar.fc")
  end
end
