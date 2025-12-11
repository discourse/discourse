# frozen_string_literal: true

RSpec.describe "Sidebar New Topic Button", system: true do
  before { upload_theme }
  fab!(:group)
  fab!(:user) { Fabricate(:user, trust_level: 3, groups: [group]) }
  fab!(:private_category) do
    c = Fabricate(:category_with_definition)
    c.set_permissions(group => :readonly)
    c.save
    c
  end

  fab!(:subcategory) do
    Fabricate(
      :private_category,
      parent_category_id: private_category.id,
      group: group,
      permission_type: 1,
    )
  end

  fab!(:category_with_no_subcategory) do
    Fabricate(:category_with_group_and_permission, group: group, permission_type: 3)
  end

  let(:category_page) { PageObjects::Pages::Category.new }

  context "for signed in users" do
    before { sign_in(user) }

    it "renders the new topic button in the sidebar" do
      visit("/latest")
      expect(page).to have_css(".sidebar-new-topic-button__wrapper")
      expect(page).to have_css(".sidebar-new-topic-button:not(.disabled)")
      expect(page).to have_css(".sidebar-new-topic-button.can-create-topic")
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

    context "when the category has a subcategory where user can post" do
      it "does not disable button when visiting read-only category and has the can-create-topic class" do
        category_page.visit(private_category)

        expect(page).to have_no_css(".sidebar-new-topic-button[disabled]")

        category_page.visit(category)

        expect(page).to have_no_css(".sidebar-new-topic-button[disabled]")
        expect(page).to have_css(".sidebar-new-topic-button.can-create-topic")
      end
    end

    context "when category has no subcategory where user can post" do
      it "adds cannot-create-topic class to the button" do
        category_page.visit(category_with_no_subcategory)
        expect(page).to have_css(".sidebar-new-topic-button.cannot-create-topic")
        expect(page).to have_no_css(".sidebar-new-topic-button.can-create-topic")
      end

      context "when visiting staff-only tag as non-staff user" do
        fab!(:staff_tag) { Fabricate(:tag, name: "staff-only") }

        before do
          staff_tag.update!(target_tag_id: nil, pm_topic_count: 0, public_topic_count: 0)
          SiteSetting.staff_tags = staff_tag.name
        end

        it "adds cannot-create-topic class to the button" do
          visit("/tag/#{staff_tag.name}")
          expect(page).to have_css(".sidebar-new-topic-button.cannot-create-topic")
          expect(page).to have_no_css(".sidebar-new-topic-button.can-create-topic")
        end
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
end
