# frozen_string_literal: true

describe "Edit Category Tags" do
  with_select_controls(false)

  fab!(:admin)
  fab!(:category)
  fab!(:tag1) { Fabricate(:tag, name: "tag1") }
  fab!(:tag2) { Fabricate(:tag, name: "tag2") }
  fab!(:tag3) { Fabricate(:tag, name: "tag3") }
  fab!(:tag_group) { Fabricate(:tag_group, name: "My Group", tags: [tag2]) }
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:allowed_tags_chooser) do
    PageObjects::Components::SelectKit.new("#control-allowed_tags .tag-chooser")
  end
  let(:allowed_tag_groups_chooser) do
    PageObjects::Components::SelectKit.new("#category-allowed-tag-groups.tag-group-chooser")
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

  context "with the new select controls" do
    with_select_controls(true)

    let(:allowed_tags_chooser) do
      PageObjects::Components::UiKit::DSelect.at("#control-allowed_tags .tag-chooser")
    end
    let(:allowed_tag_groups_chooser) do
      PageObjects::Components::UiKit::DSelect.at("#category-allowed-tag-groups")
    end
    let(:required_tag_group_chooser) do
      PageObjects::Components::UiKit::DSelect.at(
        "[data-name='required_tag_groups.0.name'] .tag-group-chooser",
      )
    end

    it "restricts topic tags to those picked with the new select controls" do
      category_page.visit_tags(category)

      allowed_tags_chooser.open
      allowed_tags_chooser.search("tag1")
      allowed_tags_chooser.select_name("tag1")
      allowed_tags_chooser.close

      allowed_tag_groups_chooser.open
      allowed_tag_groups_chooser.search("My Group")
      allowed_tag_groups_chooser.select_name("My Group")
      allowed_tag_groups_chooser.close

      category_page.save_settings

      try_until_success(reason: "saving the category tags") do
        expect(category.reload.tags.pluck(:name)).to contain_exactly("tag1")
        expect(category.tag_groups).to contain_exactly(tag_group)
      end

      visit "/new-topic?category_id=#{category.id}"
      composer.fill_title("Test topic with restricted tags")

      tag_chooser = PageObjects::Components::UiKit::DSelect.at(".tags-input .mini-tag-chooser")
      tag_chooser.open
      expect(tag_chooser).to have_option_name("tag1")
      expect(tag_chooser).to have_option_name("tag2") # from tag group
      expect(tag_chooser).to have_no_option_name("tag3")
    end

    it "sets a required tag group with the new select controls" do
      category_page.visit_tags(category)

      find(".add-required-tag-group").click
      required_tag_group_chooser.open
      required_tag_group_chooser.search("My Group")
      required_tag_group_chooser.select_name("My Group")
      required_tag_group_chooser.close

      expect(required_tag_group_chooser).to have_selected_name("My Group")

      category_page.save_settings

      try_until_success(reason: "saving the required tag group") do
        required = category.reload.category_required_tag_groups
        expect(required.map(&:tag_group)).to contain_exactly(tag_group)
        expect(required.first.min_count).to eq(1)
      end

      page.refresh

      expect(required_tag_group_chooser).to have_selected_name("My Group")
    end
  end
end
