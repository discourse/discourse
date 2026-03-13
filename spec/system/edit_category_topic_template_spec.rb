# frozen_string_literal: true

describe "Edit category topic template", type: :system do
  fab!(:admin)
  fab!(:category)

  before { sign_in admin }

  let(:toasts) { PageObjects::Components::Toasts.new }

  it "saves and displays a custom topic title placeholder" do
    visit "/c/#{category.slug}/edit/topic-template"
    find("#category-topic-title-placeholder").fill_in(with: "Describe your issue briefly")
    find("#save-category").click

    expect(toasts).to have_success(I18n.t("js.saved"))
    expect(category.reload.topic_title_placeholder).to eq("Describe your issue briefly")
  end
end
