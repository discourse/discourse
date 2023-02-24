# frozen_string_literal: true

describe "Sidebar categories sections", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category, description: "Movies/TV series") }
  fab!(:caregory_sideba_section_link) do
    Fabricate(:category_sidebar_section_link, linkable: category, user: user)
  end

  it "shows categories title on hover" do
    sign_in user
    visit("/latest")
    expect(first("#sidebar-section-content-categories .sidebar-section-link")["title"]).to eq(
      "Movies/TV series",
    )
  end
end
