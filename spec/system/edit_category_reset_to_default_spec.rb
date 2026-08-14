# frozen_string_literal: true

describe "Edit Category Reset To Default" do
  fab!(:admin)
  fab!(:category) { Fabricate(:category, sort_order: "likes", default_view: "top") }

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }

  before { sign_in(admin) }

  it "lets an admin put the sort order and the default view back to the default" do
    category_page.visit_appearance(category)

    expect(form.field("sort_order")).to have_value("likes")
    expect(form.field("default_view")).to have_value("top")

    form.field("sort_order").select_none
    form.field("default_view").select_none
    category_page.save_settings

    try_until_success do
      category.reload
      expect(category.sort_order).to eq(nil)
      expect(category.default_view).to eq(nil)
    end

    page.refresh

    expect(form.field("sort_order")).to have_no_value
    expect(form.field("default_view")).to have_no_value
  end
end
