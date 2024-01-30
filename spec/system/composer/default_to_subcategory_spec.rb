# frozen_string_literal: true

describe "Default to Subcategory when parent Category doesn't allow posting", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:group_user) { Fabricate(:group_user, user: user, group: group) }
  fab!(:default_latest_category) { Fabricate(:category, name: "General") }
  fab!(:category) { Fabricate(:private_category, group: group, permission_type: 3) }
  fab!(:subcategory) do
    Fabricate(:private_category, parent_category_id: category.id, group: group, permission_type: 1)
  end
  fab!(:category_with_no_subcategory) do
    Fabricate(:category_with_group_and_permission, group: group, permission_type: 3)
  end
  let(:category_page) { PageObjects::Pages::Category.new }

  describe "anon user" do
    it "can visit the category" do
      category_page.visit(category_with_no_subcategory)
      select_kit = PageObjects::Components::SelectKit.new(".navigation-container")
      expect(select_kit).to have_selected_value(category_with_no_subcategory.id)
    end
  end

  describe "logged in user" do
    before { sign_in(user) }
    describe "default_subcategory_on_read_only_category setting enabled and can't post on parent category" do
      before { SiteSetting.default_subcategory_on_read_only_category = true }

      describe "default_composer_category set" do
        before { SiteSetting.default_composer_category = default_latest_category.id }
        describe "Can't post on parent category" do
          describe "Category has subcategory" do
            it "should have 'New Topic' button enabled and default Subcategory set in the composer" do
              category_page.visit(category)
              expect(category_page).to have_button("New Topic", disabled: false)
              category_page.new_topic_button.click
              select_kit =
                PageObjects::Components::SelectKit.new("#reply-control.open .category-chooser")
              expect(select_kit).to have_selected_value(subcategory.id)
            end
          end
          describe "Category does not have subcategory" do
            it "should have the 'New Topic' button disabled" do
              category_page.visit(category_with_no_subcategory)
              expect(category_page).to have_button("New Topic", disabled: true)
            end
          end
        end
        describe "Can post on home page" do
          it "should have the default category set in the composer" do
            page.visit("latest")
            expect(page).to have_button("New Topic", disabled: false)
            page.find("#create-topic").click
            select_kit =
              PageObjects::Components::SelectKit.new("#reply-control.open .category-chooser")
            expect(select_kit).to have_selected_value(default_latest_category.id)
          end
        end
      end

      describe "default_composer_category not set" do
        before do
          SiteSetting.default_composer_category = ""
          SiteSetting.allow_uncategorized_topics = false
        end
        describe "Can't post on parent category" do
          describe "Category does not have subcategory" do
            it "should have the 'New Topic' button disabled" do
              category_page.visit(category_with_no_subcategory)
              expect(category_page).to have_button("New Topic", disabled: true)
            end
          end
        end
        describe "Can post on home page" do
          it "composer should open" do
            page.visit("latest")
            expect(page).to have_button("New Topic", disabled: false)
            page.find("#create-topic").click

            select_kit =
              PageObjects::Components::SelectKit.new("#reply-control.open .category-chooser")
            expect(select_kit).to have_selected_name("category&hellip;")
          end
        end
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
end
