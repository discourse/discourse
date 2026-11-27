# frozen_string_literal: true

describe "Creating a subcategory as a category group moderator" do
  fab!(:moderator) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:category) { Fabricate(:private_category, group:) }

  it "creates a subcategory from its parent category page" do
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.category_group_moderators_can_create_subcategories = true
    group.add(moderator)
    Fabricate(:category_moderation_group, category:, group:)
    sign_in(moderator)

    PageObjects::Pages::Category.new.visit(category)
    find(".create-subcategory").click

    form = PageObjects::Components::FormKit.new(".create-subcategory-modal .form-kit")
    form.field("name").fill_in("Moderated subcategory")
    find(".create-subcategory-modal .btn-primary").click

    expect(page).to have_no_css(".create-subcategory-modal")
    child = category.subcategories.find_by!(name: "Moderated subcategory")
    expect(page).to have_current_path(child.url)
    expect(child).to be_read_restricted
    expect(child.moderating_group_ids).to eq([group.id])
  end
end
