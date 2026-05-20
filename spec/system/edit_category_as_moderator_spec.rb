# frozen_string_literal: true

RSpec.describe "Edit category as moderator" do
  fab!(:moderator)
  fab!(:category)
  fab!(:visible_tag) { Fabricate(:tag, name: "visible-tag") }
  fab!(:visible_tag_group) { Fabricate(:tag_group, name: "visible-group") }
  fab!(:admin_only_tag) { Fabricate(:tag, name: "admin-only-tag") }

  fab!(:admin_only_tag_group) do
    Fabricate(
      :tag_group,
      name: "admin-only-group",
      permissions: {
        "admins" => 1,
      },
      tag_names: [admin_only_tag.name],
    )
  end

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:allowed_tags_chooser) do
    PageObjects::Components::SelectKit.new("#control-allowed_tags .tag-chooser")
  end
  let(:allowed_tag_groups_chooser) do
    PageObjects::Components::SelectKit.new("#category-allowed-tag-groups.tag-group-chooser")
  end

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.moderators_manage_categories = true

    category.tags << visible_tag
    category.tags << admin_only_tag
    category.tag_groups << visible_tag_group
    category.tag_groups << admin_only_tag_group

    sign_in(moderator)
  end

  it "preserves visible tag and tag-group associations across an unrelated save" do
    category_page.visit_general(category)
    form.field("color").fill_in("abcdef")
    category_page.save_settings

    category_page.visit_tags(category)

    expect(allowed_tags_chooser).to have_selected_name(visible_tag.name)
    expect(allowed_tag_groups_chooser).to have_selected_name(visible_tag_group.name)
  end
end
