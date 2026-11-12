# frozen_string_literal: true

RSpec.describe "Admin category management" do
  fab!(:admin)

  fab!(:public_category) do
    Fabricate(
      :category,
      name: "Alpha Guides",
      slug: "alpha-guides",
      description: "Documentation and onboarding articles.",
      icon: "wrench",
      style_type: "icon",
      topic_count: 12,
    )
  end

  fab!(:restricted_category) do
    Fabricate(
      :private_category,
      group: Group[:staff],
      name: "Beta Staff",
      slug: "beta-staff",
      description: "Private coordination for staff.",
      emoji: "rocket",
      style_type: "emoji",
      topic_count: 3,
    )
  end

  let(:category_management_page) { PageObjects::Pages::AdminCategoryManagement.new }

  before { sign_in(admin) }

  it "lets admins review and filter all categories", :aggregate_failures do
    category_management_page.visit_all

    expect(category_management_page).to have_category_details(
      public_category,
      description: "Documentation and onboarding articles.",
      visibility: I18n.t("admin_js.admin.config.category_management.visibility.public"),
      topic_count: 12,
    )
    expect(category_management_page).to have_category_icon(public_category)
    expect(category_management_page).to have_open_settings_link(public_category)
    expect(category_management_page).to have_category_details(
      restricted_category,
      description: "Private coordination for staff.",
      visibility: I18n.t("admin_js.admin.config.category_management.visibility.restricted"),
      topic_count: 3,
    )
    expect(category_management_page).to have_category_emoji(restricted_category)

    category_management_page.filter_by_name("Alpha")

    expect(category_management_page).to have_category(public_category)
    expect(category_management_page).to have_no_category(restricted_category)

    category_management_page.open_settings(public_category)
    expect(page).to have_current_path("#{public_category.slug_url_without_id}/edit/general")
  end
end
