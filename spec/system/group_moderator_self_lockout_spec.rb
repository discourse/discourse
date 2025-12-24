# frozen_string_literal: true

describe "Group moderator self-lockout warning" do
  fab!(:moderator)
  fab!(:group)

  let(:group_page) { PageObjects::Pages::Group.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:visibility_chooser) do
    PageObjects::Components::SelectKit.new(".groups-form-visibility-level")
  end
  let(:members_visibility_chooser) do
    PageObjects::Components::SelectKit.new(".groups-form-members-visibility-level")
  end
  let(:member_dropdown) { PageObjects::Components::SelectKit.new(".group-member-dropdown") }

  before { SiteSetting.moderators_manage_groups = true }

  def visit_interaction_settings
    group_page.visit(group)
    group_page.click_manage
    page.find(".user-secondary-navigation li", text: "Interaction").click
  end

  context "when non-owner moderator changes visibility to 'Owners only'" do
    before { sign_in(moderator) }

    it "shows confirmation dialog for visibility_level change" do
      visit_interaction_settings
      visibility_chooser.expand
      visibility_chooser.select_row_by_value(Group.visibility_levels[:owners])
      group_page.click_save

      expect(dialog).to be_open
      expect(dialog).to have_content(I18n.t("js.groups.manage.interaction.self_lockout"))
    end

    it "shows confirmation dialog for members_visibility_level change" do
      visit_interaction_settings
      members_visibility_chooser.expand
      members_visibility_chooser.select_row_by_value(Group.visibility_levels[:owners])
      group_page.click_save

      expect(dialog).to be_open
      expect(dialog).to have_content(I18n.t("js.groups.manage.interaction.self_lockout"))
    end

    it "saves when confirmed" do
      visit_interaction_settings
      visibility_chooser.expand
      visibility_chooser.select_row_by_value(Group.visibility_levels[:owners])
      group_page.click_save
      dialog.click_yes

      expect(page).to have_no_current_path(%r{/g/#{group.name}/manage})
      expect(group.reload.visibility_level).to eq(Group.visibility_levels[:owners])
    end

    it "does not save when cancelled" do
      visit_interaction_settings
      visibility_chooser.expand
      visibility_chooser.select_row_by_value(Group.visibility_levels[:owners])
      group_page.click_save
      dialog.click_no

      visit_interaction_settings
      expect(visibility_chooser).to have_selected_value(Group.visibility_levels[:public])
    end

    it "saves without dialog for non-restrictive visibility levels" do
      visit_interaction_settings
      visibility_chooser.expand
      visibility_chooser.select_row_by_value(Group.visibility_levels[:staff])
      group_page.click_save

      expect(dialog).to be_closed
      expect(group.reload.visibility_level).to eq(Group.visibility_levels[:staff])
    end
  end

  context "when owner moderator changes visibility to 'Owners only'" do
    before do
      group.add_owner(moderator)
      sign_in(moderator)
    end

    it "saves without showing dialog" do
      visit_interaction_settings
      visibility_chooser.expand
      visibility_chooser.select_row_by_value(Group.visibility_levels[:owners])
      group_page.click_save

      expect(dialog).to be_closed
      expect(group.reload.visibility_level).to eq(Group.visibility_levels[:owners])
    end
  end

  context "when owner moderator removes self with restrictive visibility" do
    before do
      group.update!(visibility_level: Group.visibility_levels[:owners])
      group.add_owner(moderator)
      sign_in(moderator)
    end

    it "shows confirmation dialog when removing self as owner" do
      group_page.visit(group)
      member_dropdown.expand
      member_dropdown.select_row_by_value("removeOwner")

      expect(dialog).to be_open
      expect(dialog).to have_content(I18n.t("js.groups.members.remove_owner_self_lockout"))
    end

    it "shows confirmation dialog when removing self as member" do
      group_page.visit(group)
      member_dropdown.expand
      member_dropdown.select_row_by_value("removeMember")

      expect(dialog).to be_open
      expect(dialog).to have_content(I18n.t("js.groups.members.remove_member_self_lockout"))
    end

    it "does not remove when cancelled" do
      group_page.visit(group)
      member_dropdown.expand
      member_dropdown.select_row_by_value("removeOwner")
      dialog.click_no

      expect(group.reload.group_users.find_by(user: moderator).owner).to be true
    end
  end
end
