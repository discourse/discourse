# frozen_string_literal: true

describe "Simplified Category Creation" do
  fab!(:admin)
  fab!(:group)
  fab!(:category)

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:category_type_card) { PageObjects::Components::CategoryTypeCard.new }
  let(:category_permission_row) { PageObjects::Components::CategoryPermissionRow.new }

  before do
    SiteSetting.enable_simplified_category_creation = true
    sign_in(admin)
  end

  describe "Selecting category type when setting up a new category" do
    it "automatically skips category type selection when only one type (discussion) is available" do
      visit("/new-category/setup")
      expect(page).to have_content(I18n.t("js.category.create_with_type", typeName: "discussion"))
      expect(page).to have_current_path("/new-category/general")
    end

    context "when multiple types are available" do
      class MockCategoryType < ::Categories::Types::Base
        type_id :mock_type

        class << self
          def category_matches?(category)
            true
          end

          def find_matches
            Category.none
          end
        end
      end

      before { Categories::TypeRegistry.register(MockCategoryType) }
      after { Categories::TypeRegistry.reset! }

      it "shows the category type selection cards" do
        visit("/new-category/setup")

        expect(category_type_card).to have_type_card("mock_type")
        expect(category_type_card).to have_type_card("discussion")

        category_type_card.find_type_card("discussion").click
        expect(page).to have_content(I18n.t("js.category.create_with_type", typeName: "discussion"))
        expect(page).to have_current_path("/new-category/general")
      end
    end
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

    it "shows error when icon is missing" do
      category_page.visit_new_category

      form.field("name").fill_in("Test Category")

      icon_picker = PageObjects::Components::SelectKit.new(".form-kit__control-icon")
      icon_picker.expand
      icon_picker.clear
      icon_picker.collapse

      category_page.save_settings

      expect(form.field("icon")).to have_errors(I18n.t("js.category.validations.icon_required"))
    end

    it "shows advanced tabs when toggled" do
      category_page.visit_general(category)

      category_page.toggle_advanced_settings

      expect(page).to have_css(".edit-category-security")
      expect(page).to have_css(".edit-category-settings")
    end

    it "preserves permission types when adding a new access group on general tab" do
      group2 = Fabricate(:group)

      category_page.visit_new_category

      form.field("name").fill_in("Permission Test")
      form.choose_conditional("group_restricted")

      group_chooser = PageObjects::Components::SelectKit.new(".group-chooser")
      group_chooser.expand
      group_chooser.select_row_by_value(group.id)
      group_chooser.collapse

      category_page.toggle_advanced_settings
      find(".edit-category-security a").click
      category_permission_row.toggle_group_permission(group.name, "reply")

      find(".edit-category-general a").click
      group_chooser.expand
      group_chooser.select_row_by_value(group2.id)
      group_chooser.collapse

      find(".edit-category-security a").click

      expect(page).to have_no_css(
        "#{category_permission_row.group_permission_row_selector(group.name)} .reply-granted",
      )
    end

    it "automatically switches to private when selecting a restricted parent" do
      restricted_parent =
        Fabricate(:category, name: "Restricted Parent", permissions: { group.name => :full })

      category_page.visit_new_category

      parent_chooser = PageObjects::Components::SelectKit.new(".category-chooser")
      parent_chooser.expand
      parent_chooser.select_row_by_value(restricted_parent.id)

      expect(page).to have_css(".group-chooser")
    end

    it "shows inherited groups when selecting a restricted parent" do
      restricted_parent =
        Fabricate(:category, name: "Restricted Parent", permissions: { group.name => :full })

      category_page.visit_new_category

      parent_chooser = PageObjects::Components::SelectKit.new(".category-chooser")
      parent_chooser.expand
      parent_chooser.select_row_by_value(restricted_parent.id)

      group_chooser = PageObjects::Components::SelectKit.new(".group-chooser")
      expect(group_chooser).to have_selected_name(group.name)
    end
    it "opens the composer to edit the category description and updates it after save" do
      category_page.visit_general(category)

      composer = PageObjects::Components::Composer.new

      find(".edit-category-description").click
      expect(composer).to be_opened

      composer.fill_content("Updated category description")
      composer.submit

      expect(composer).to be_closed
      expect(page).to have_css(".edit-category-description-container .readonly-field")
      expect(page).to have_content("Updated category description")
      expect(page).to have_css(
        ".fk-d-default-toast",
        text: I18n.t("js.category.description_updated"),
      )
    end
  end

  describe "Security Tab" do
    fab!(:private_category) { Fabricate(:private_category, group:) }

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

    it "resets security settings when navigating from edit to new category" do
      category_page.visit_general(private_category)
      expect(page).to have_css(".group-chooser")

      category_page.visit_new_category
      expect(page).to have_no_css(".group-chooser")
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

      form.field("category_setting.require_topic_approval").toggle
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
    fab!(:tag_group) { Fabricate(:tag_group, name: "My Group") }

    let(:allowed_tag_groups_chooser) do
      PageObjects::Components::SelectKit.new("#category-allowed-tag-groups")
    end

    before do
      SiteSetting.tagging_enabled = true
      tag_group.tags = [tag1]
      tag_group.save!
    end

    it "restricts allowed tags" do
      category_page.visit_tags(category)

      form.field("allowed_tags").select("tag1")
      category_page.save_settings

      expect(category.reload.tags.map(&:name)).to include("tag1")

      category_page.visit_tags(category)

      expect(form.field("allowed_tags")).to have_selected_names("tag1")
    end

    it "sets minimum required tags" do
      category_page.visit_tags(category)

      form.field("minimum_required_tags").fill_in("2")
      category_page.save_settings

      expect(category.reload.minimum_required_tags).to eq(2)
    end

    it "sets required tag groups" do
      category_page.visit_tags(category)

      allowed_tag_groups_chooser.expand
      allowed_tag_groups_chooser.select_row_by_name("My Group")
      allowed_tag_groups_chooser.collapse
      category_page.save_settings

      expect(category.reload.tag_groups.map(&:name)).to include("My Group")

      category_page.visit_tags(category)

      expect(allowed_tag_groups_chooser).to have_selected_names("My Group")
    end
  end
end
