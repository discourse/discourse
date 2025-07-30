# frozen_string_literal: true

RSpec.describe "Sidebar New Topic Button", system: true do
  before { upload_theme }
  fab!(:group)
  fab!(:user) { Fabricate(:user, trust_level: 3, groups: [group]) }
  fab!(:category)
  fab!(:private_category) do
    c = Fabricate(:category_with_definition)
    c.set_permissions(group => :readonly)
    c.save
    c
  end

  context "for signed in users" do
    before { sign_in(user) }

    it "renders the new topic button in the sidebar" do
      visit("/latest")
      expect(page).to have_css(".sidebar-new-topic-button__wrapper")
      expect(page).to have_css(".sidebar-new-topic-button:not(.disabled)")
    end

    it "opens the composer when clicked" do
      visit("/")
      find(".sidebar-new-topic-button").click
      expect(page).to have_css("#reply-title")
    end

    it "shows draft menu when drafts exist" do
      Draft.create!(user: user, draft_key: "topic_1", data: {})

      visit("/")
      expect(page).to have_css(".sidebar-new-topic-button__wrapper .topic-drafts-menu-trigger")
    end

    it "disables button when visiting read-only category" do
      visit("/c/#{private_category.slug}/#{private_category.id}")

      expect(page).to have_css(".sidebar-new-topic-button[disabled]")

      visit("/c/#{category.slug}/#{category.id}")

      expect(page).to have_no_css(".sidebar-new-topic-button[disabled]")
    end
  end

  context "for anon" do
    it "does not render the sidebar button for anons" do
      visit("/latest")
      expect(page).not_to have_css(".sidebar-new-topic-button__wrapper")
      expect(page).not_to have_css(".sidebar-new-topic-button:not(.disabled)")
    end
  end
end
