# frozen_string_literal: true

describe "Default to Subcategory when parent Category doesn't allow posting",
         type: :system,
         js: true do
  fab!(:user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group) }
  fab!(:group_user) { Fabricate(:group_user, user: user, group: group) }
  fab!(:category) { Fabricate(:private_category, group: group, permission_type: 3) }
  fab!(:subcategory) do
    Fabricate(:private_category, parent_category_id: category.id, group: group, permission_type: 1)
  end
  let(:category_page) { PageObjects::Pages::Category.new }
  before { sign_in(user) }

  describe "Setting enabled and can't post on parent category" do
    before { SiteSetting.default_subcategory_on_read_only_category = true }

    it "should have 'New Topic' button enabled and default Subcategory set in the composer" do
      category_page.visit(category)
      expect(category_page).to have_button("New Topic", disabled: false)
      category_page.new_topic_button.click
      select_kit =
        PageObjects::Components::SelectKit.new(page.find("#reply-control.open .category-chooser"))
      expect(select_kit).to have_selected_value(subcategory.id)
    end
  end

  describe "Setting disabled and can't post on parent category" do
    before { SiteSetting.default_subcategory_on_read_only_category = false }

    it "should have 'New Topic' button disabled" do
      category_page.visit(category)
      expect(category_page).to have_button("New Topic", disabled: true)
    end
  end
end
