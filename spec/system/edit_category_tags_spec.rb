# frozen_string_literal: true

describe "Edit Category Tags", type: :system do
  fab!(:admin)
  fab!(:category)
  fab!(:tag1) { Fabricate(:tag, name: "tag1") }
  fab!(:tag2) { Fabricate(:tag, name: "tag2") }
  fab!(:tag3) { Fabricate(:tag, name: "tag3") }
  fab!(:tag_group) { Fabricate(:tag_group, name: "My Group", tags: [tag2]) }
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:allowed_tags_chooser) { PageObjects::Components::SelectKit.new("#category-allowed-tags") }
  let(:allowed_tag_groups_chooser) do
    PageObjects::Components::SelectKit.new("#category-allowed-tag-groups")
  end
  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.tagging_enabled = true
    sign_in(admin)
  end

  it "can select restricted tags and tag groups" do
    category_page.visit_tags(category)

    allowed_tags_chooser.expand
    allowed_tags_chooser.select_row_by_name("tag1")
    allowed_tags_chooser.collapse

    allowed_tag_groups_chooser.expand
    allowed_tag_groups_chooser.select_row_by_name("My Group")

    category_page.save_settings

    visit "/new-topic?category_id=#{category.id}"
    composer.fill_title("Test topic with restricted tags")

    tag_chooser = PageObjects::Components::SelectKit.new(".mini-tag-chooser")
    tag_chooser.expand
    expect(tag_chooser).to have_option_name("tag1")
    expect(tag_chooser).to have_option_name("tag2") # from tag group
    expect(tag_chooser).to have_no_option_name("tag3")
  end
end
