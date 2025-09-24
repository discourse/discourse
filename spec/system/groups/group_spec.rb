# frozen_string_literal: true

describe "Group", type: :system do
  let(:group_page) { PageObjects::Pages::Group.new }
  let(:group_index_page) { PageObjects::Pages::GroupIndex.new }
  let(:group_form_page) { PageObjects::Pages::GroupForm.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  fab!(:admin)
  fab!(:group)

  before { sign_in(admin) }

  describe "create a group" do
    context "when there are no existing users matching the auto e-mail domains" do
      it "creates a new group" do
        group_index_page.visit
        group_index_page.click_new_group

        group_form_page.fill_in("name", with: "illuminati")
        group_form_page.fill_in("full_name", with: "The Illuminati")

        expect(group_form_page).to have_css(".tip.good")

        group_form_page.add_automatic_email_domain("illumi.net")
        group_form_page.click_save

        expect(page).to have_current_path("/g/illuminati")
      end
    end

    context "when there are existing users matching the auto e-mail domains" do
      before { Fabricate(:user, email: "ted@illumi.net") }

      it "notifies about automatic members and creates a new group" do
        group_index_page.visit
        group_index_page.click_new_group

        group_form_page.fill_in("name", with: "illuminati")
        group_form_page.fill_in("full_name", with: "The Illuminati")

        expect(group_form_page).to have_css(".tip.good")

        group_form_page.add_automatic_email_domain("illumi.net")

        group_form_page.click_save
        expect(dialog).to be_open
        expect(dialog).to have_content(
          I18n.t(
            "admin_js.admin.groups.manage.membership.automatic_membership_user_count",
            count: 1,
          ),
        )

        dialog.click_no
        expect(page).to have_current_path("/g/custom/new")

        group_form_page.click_save
        expect(dialog).to be_open

        dialog.click_yes
        expect(page).to have_current_path("/g/illuminati")
      end
    end
  end

  describe "update a group" do
    it "creates a new group" do
      group_page.visit(group)

      group_page.click_manage
      group_page.click_membership

      group_page.fill_in("title", with: "The Illuminati")

      group_page.click_save

      expect(group_page).to have_css(".group-manage-save-button span", text: "Saved!")
    end
  end

  describe "group owners management" do
    fab!(:owner_user) { Fabricate(:user) }
    fab!(:co_owner) { Fabricate(:user) }

    it "persists added owner and shows it after reload" do
      group_page.visit(group)

      group_page.click_manage
      group_page.click_membership

      # Add an owner via the owner selector
      select_kit = PageObjects::Components::SelectKit.new(".email-group-user-chooser")
      select_kit.expand
      select_kit.search(owner_user.username)
      select_kit.select_row_by_value(owner_user.username)

      # Click save for the membership page
      group_page.click_save

      # Reload the membership page
      page.visit("/g/#{group.name}/manage/membership")

      # Expand and search to hydrate chooser content, then verify selection visible
      select_kit = PageObjects::Components::SelectKit.new(".email-group-user-chooser")
      select_kit.expand
      select_kit.search(owner_user.username)
      expect(page).to have_css(
        ".email-group-user-chooser .selected-choice[data-value='#{owner_user.username}']",
      )
    end

    it "allows non-staff owners to manage owners and defers removals until save" do
      group.add_owner(owner_user)
      group.add_owner(co_owner)
      group.add(owner_user)
      group.add(co_owner)

      sign_in(owner_user)

      group_page.visit(group)

      group_page.click_manage
      group_page.click_membership

      select_kit = PageObjects::Components::SelectKit.new(".email-group-user-chooser")
      select_kit.expand
      expect(page).to have_css(
        ".email-group-user-chooser .selected-choice[data-value='#{co_owner.username}']",
      )

      select_kit.unselect_by_value(co_owner.username)
      expect(page).to have_no_css(
        ".email-group-user-chooser .selected-choice[data-value='#{co_owner.username}']",
      )

      page.visit("/g/#{group.name}/manage/membership")
      select_kit = PageObjects::Components::SelectKit.new(".email-group-user-chooser")
      select_kit.expand
      expect(page).to have_css(
        ".email-group-user-chooser .selected-choice[data-value='#{co_owner.username}']",
      )

      select_kit.unselect_by_value(co_owner.username)
      group_page.click_save
      expect(group_page).to have_css(".group-manage-save-button span", text: "Saved!")

      page.visit("/g/#{group.name}/manage/membership")
      select_kit = PageObjects::Components::SelectKit.new(".email-group-user-chooser")
      select_kit.expand
      expect(page).to have_no_css(
        ".email-group-user-chooser .selected-choice[data-value='#{co_owner.username}']",
      )

      select_kit.unselect_by_value(owner_user.username)

      expect(dialog).to be_open
      expect(dialog).to have_content(
        I18n.t("js.groups.manage.membership.remove_self_warning", group_name: group.name),
      )

      dialog.click_ok

      group_page.click_save
      expect(group_page).to have_css(".group-manage-save-button span", text: "Saved!")

      page.visit("/g/#{group.name}/manage/membership")
      expect(page).not_to have_current_path("/g/#{group.name}/manage/membership")
      expect(page).to have_no_css(".user-primary-navigation .manage")
    end
  end

  describe "delete a group" do
    it "redirects to groups index page" do
      group_page.visit(group)

      group_page.delete_group

      expect(page).to have_current_path("/g")
    end
  end
end
