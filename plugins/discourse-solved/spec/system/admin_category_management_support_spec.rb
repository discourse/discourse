# frozen_string_literal: true

RSpec.describe "Admin category management support tab" do
  fab!(:admin)

  fab!(:support_category) do
    Fabricate(
      :category,
      name: "Support Queue",
      slug: "support-queue",
      description: "Questions that need accepted answers.",
      topic_count: 9,
    ).tap do |category|
      DiscourseSolved::Categories::Types::Support.configure_category(
        category,
        guardian: admin.guardian,
      )
    end
  end

  fab!(:discussion_category) do
    Fabricate(
      :category,
      name: "General Discussion",
      slug: "general-discussion",
      description: "Open community conversation.",
      topic_count: 4,
    )
  end

  let(:category_management_page) { PageObjects::Pages::AdminCategoryManagement.new }

  before do
    SiteSetting.solved_enabled = true
    sign_in(admin)
  end

  it "lets admins see only support categories" do
    category_management_page.visit_support

    expect(category_management_page).to have_category(support_category)
    expect(category_management_page).to have_no_category(discussion_category)
  end
end
