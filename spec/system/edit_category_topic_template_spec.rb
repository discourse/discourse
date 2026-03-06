# frozen_string_literal: true

describe "Edit category topic template", type: :system do
  fab!(:admin)
  fab!(:category)

  before { sign_in admin }

  it "saves and displays a custom topic title placeholder" do
    visit "/c/#{category.slug}/edit/topic-template"
    find("#category-topic-title-placeholder").fill_in(with: "Describe your issue briefly")
    find("#save-category").click

    visit "/c/#{category.slug}/edit/topic-template"
    expect(find("#category-topic-title-placeholder").value).to eq("Describe your issue briefly")
  end
end
