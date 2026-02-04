# frozen_string_literal: true

describe "Simplified Category Creation" do
  fab!(:admin)
  fab!(:group)
  fab!(:category)

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:category_permission_row) { PageObjects::Components::CategoryPermissionRow.new }

  before do
    SiteSetting.enable_simplified_category_creation = true
    sign_in(admin)
  end

  describe "General Tab" do
    it "creates a basic category with name and color" do
      category_page.visit_new_category

      form.field("name").fill_in("Test Category")
      form.field("color").fill_in("FF5733")
      category_page.save_settings

      created_category = Category.find_by(name: "Test Category")
      expect(created_category).to be_present
      expect(created_category.color).to eq("FF5733")
    end

    it "edits an existing category name" do
      category_page.visit_general(category)

      form.field("name").fill_in("Updated Name")
      category_page.save_settings

      expect(category.reload.name).to eq("Updated Name")
    end

    it "changes category color" do
      category_page.visit_general(category)

      form.field("color").fill_in("123ABC")
      category_page.save_settings

      expect(category.reload.color).to eq("123ABC")
    end

    it "selects a parent category" do
      parent_category = Fabricate(:category, name: "Parent")
      category_page.visit_general(category)

      parent_chooser = PageObjects::Components::SelectKit.new(".category-chooser")
      parent_chooser.expand
      parent_chooser.select_row_by_value(parent_category.id)
      category_page.save_settings

      expect(category.reload.parent_category_id).to eq(parent_category.id)
    end

    it "switches to group restricted visibility" do
      category_page.visit_general(category)

      form.choose_conditional("group_restricted")

      group_chooser = PageObjects::Components::SelectKit.new(".group-chooser")
      group_chooser.expand
      group_chooser.select_row_by_value(group.id)
      group_chooser.collapse
      category_page.save_settings

      expect(category.reload.category_groups.map(&:group_id)).to include(group.id)
    end

    it "shows error when color is invalid" do
      category_page.visit_general(category)

      form.field("color").fill_in("GGGGGG")
      category_page.save_settings

      expect(page).to have_content("Color is invalid")
    end

    it "shows advanced tabs when toggled" do
      category_page.visit_general(category)

      category_page.toggle_advanced_settings

      expect(page).to have_css(".edit-category-security")
      expect(page).to have_css(".edit-category-settings")
    end
  end

  describe "Security Tab" do
    before do
      CategoryGroup.create!(
        category:,
        group: Group.find(Group::AUTO_GROUPS[:everyone]),
        permission_type: CategoryGroup.permission_types[:readonly],
      )
      CategoryGroup.create!(
        category:,
        group:,
        permission_type: CategoryGroup.permission_types[:readonly],
      )
    end

    it "removes a group permission" do
      category_page.visit_security(category)

      category_permission_row.remove_group_permission(group.name)
      category_page.save_settings

      expect(category.reload.category_groups.map(&:group_id)).not_to include(group.id)
    end

    it "modifies a group permission (toggle reply)" do
      category_page.visit_security(category)

      category_permission_row.toggle_group_permission(group.name, "reply")
      category_page.save_settings

      expect(category.reload.category_groups.find_by(group:).permission_type).to eq(
        CategoryGroup.permission_types[:create_post],
      )
    end
  end

  describe "Settings Tab" do
    it "enables topic approval requirement" do
      category_page.visit_settings(category)

      category_page.toggle_checkbox(I18n.t("js.category.require_topic_approval"))
      category_page.save_settings

      expect(category.reload.require_topic_approval?).to eq(true)
    end
  end

  describe "Images Tab" do
    before do
      SiteSetting.authorized_extensions = ""
      SiteSetting.authorized_extensions_for_staff = "jpg|jpeg|png"
    end

    it "sets default view to latest" do
      category_page.visit_images(category)

      default_view_selector = PageObjects::Components::SelectKit.new("#category-default-view")
      default_view_selector.expand
      default_view_selector.select_row_by_value("latest")
      category_page.save_settings

      expect(category.reload.default_view).to eq("latest")
    end

    it "uploads a category logo" do
      category_page.visit_images(category)

      attach_file(
        "category-logo-uploader__input",
        Rails.root.join("spec/fixtures/images/logo.png"),
        make_visible: true,
      )
      expect(page).to have_css("#category-logo-uploader.has-image")
      category_page.save_settings

      expect(category.reload.uploaded_logo).to be_present
    end
  end

  describe "Tags Tab" do
    fab!(:tag1) { Fabricate(:tag, name: "tag1") }

    let(:allowed_tags_chooser) { PageObjects::Components::SelectKit.new("#category-allowed-tags") }

    before { SiteSetting.tagging_enabled = true }

    it "restricts allowed tags" do
      category_page.visit_tags(category)

      allowed_tags_chooser.expand
      allowed_tags_chooser.select_row_by_name("tag1")
      allowed_tags_chooser.collapse
      category_page.save_settings

      expect(category.reload.tags.map(&:name)).to include("tag1")
    end

    it "sets minimum required tags" do
      category_page.visit_tags(category)

      form.field("minimum_required_tags").fill_in("2")
      category_page.save_settings

      expect(category.reload.minimum_required_tags).to eq(2)
    end
  end
end
