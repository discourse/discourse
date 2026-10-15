# frozen_string_literal: true

describe "Group" do
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

        screenshot_marker(label: "groups")

        group_index_page.click_new_group

        browser_root
          .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
          .and(
            browser_root.locator("[id=#{"name".to_s.to_json}], [name=#{"name".to_s.to_json}]").or(
              browser_root.get_by_label("name", exact: true),
            ),
          )
          .filter(visible: true)
          .fill("illuminati")
        browser_root
          .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
          .and(
            browser_root.locator(
              "[id=#{"full_name".to_s.to_json}], [name=#{"full_name".to_s.to_json}]",
            ).or(browser_root.get_by_label("full_name", exact: true)),
          )
          .filter(visible: true)
          .fill("The Illuminati")

        expect(
          browser_root.locator(".tip.good").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)

        group_form_page.add_automatic_email_domain("illumi.net")
        group_form_page.click_save

        expect(browser_page).to PlaywrightMatchers.have_url("/g/illuminati")
      end
    end

    context "when there are existing users matching the auto e-mail domains" do
      before { Fabricate(:user, email: "ted@illumi.net") }

      it "notifies about automatic members and creates a new group" do
        group_index_page.visit
        group_index_page.click_new_group

        browser_root
          .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
          .and(
            browser_root.locator("[id=#{"name".to_s.to_json}], [name=#{"name".to_s.to_json}]").or(
              browser_root.get_by_label("name", exact: true),
            ),
          )
          .filter(visible: true)
          .fill("illuminati")
        browser_root
          .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
          .and(
            browser_root.locator(
              "[id=#{"full_name".to_s.to_json}], [name=#{"full_name".to_s.to_json}]",
            ).or(browser_root.get_by_label("full_name", exact: true)),
          )
          .filter(visible: true)
          .fill("The Illuminati")

        expect(
          browser_root.locator(".tip.good").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)

        group_form_page.add_automatic_email_domain("illumi.net")

        group_form_page.click_save
        expect(dialog).to be_open
        expect(dialog).to have_displayed_content(
          I18n.t(
            "admin_js.admin.groups.manage.membership.automatic_membership_user_count",
            count: 1,
          ),
        )

        dialog.click_no
        expect(browser_page).to PlaywrightMatchers.have_url("/g/custom/new")

        group_form_page.click_save
        expect(dialog).to be_open

        dialog.click_yes
        expect(browser_page).to PlaywrightMatchers.have_url("/g/illuminati")
      end
    end
  end

  describe "update a group" do
    it "creates a new group" do
      group_page.visit(group)

      group_page.click_manage
      group_page.click_membership

      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator("[id=#{"title".to_s.to_json}], [name=#{"title".to_s.to_json}]").or(
            browser_root.get_by_label("title", exact: true),
          ),
        )
        .filter(visible: true)
        .fill("The Illuminati")

      group_page.click_save

      expect(
        browser_root.locator(".group-manage-save-button span").filter(visible: true),
      ).to PlaywrightMatchers.contain_text([browser_text_pattern("Saved!")], useInnerText: true)
    end
  end

  describe "delete a group" do
    it "redirects to groups index page" do
      group_page.visit(group)

      group_page.delete_group

      expect(browser_page).to PlaywrightMatchers.have_url("/g")
    end
  end

  describe "update default notification level" do
    let(:default_notifications_modal) { PageObjects::Modals::GroupDefaultNotifications.new }

    fab!(:user1, :user)
    fab!(:user2, :user)

    before do
      group.update!(default_notification_level: NotificationLevels.all[:regular])
      group.add(user1)
      group.add(user2)
    end

    it "shows modal when changing notification level affects existing users" do
      group_page.visit(group)
      group_page.click_manage
      group_page.click_interaction
      group_page.select_default_notification_level(NotificationLevels.all[:tracking])
      group_page.click_save

      expect(default_notifications_modal).to be_open
      expect(default_notifications_modal).to have_displayed_content(
        I18n.t("js.groups.default_notifications.modal_description", count: 2),
      )
    end

    it "applies changes to existing users when clicking Yes" do
      group_page.visit(group)
      group_page.click_manage
      group_page.click_interaction
      group_page.select_default_notification_level(NotificationLevels.all[:tracking])
      group_page.click_save

      expect(default_notifications_modal).to be_open
      default_notifications_modal.click_yes

      expect(group_page).to have_saved
      expect(user1.group_users.find_by(group: group).reload.notification_level).to eq(
        NotificationLevels.all[:tracking],
      )
      expect(user2.group_users.find_by(group: group).reload.notification_level).to eq(
        NotificationLevels.all[:tracking],
      )
    end

    it "does not apply changes to existing users when clicking No" do
      original_level = user1.group_users.find_by(group: group).notification_level

      group_page.visit(group)
      group_page.click_manage
      group_page.click_interaction
      group_page.select_default_notification_level(NotificationLevels.all[:tracking])
      group_page.click_save

      expect(default_notifications_modal).to be_open
      default_notifications_modal.click_no

      expect(group_page).to have_saved
      expect(user1.group_users.find_by(group: group).reload.notification_level).to eq(
        original_level,
      )
    end
  end
end
