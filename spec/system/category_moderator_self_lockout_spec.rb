# frozen_string_literal: true

describe "Category moderator self-lockout warning", type: :system do
  fab!(:moderator)
  fab!(:restricted_group, :group)
  fab!(:category)
  fab!(:category_group_everyone) do
    Fabricate(
      :category_group,
      category: category,
      permission_type: CategoryGroup.permission_types[:full],
      group: Group.find(Group::AUTO_GROUPS[:everyone]),
    )
  end

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:permission_row) { PageObjects::Components::CategoryPermissionRow.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:group_chooser) { PageObjects::Components::SelectKit.new(".available-groups") }

  before { SiteSetting.moderators_manage_categories = true }

  def remove_everyone_and_add_restricted_group
    category_page.visit_security(category)
    permission_row.remove_group_permission("everyone")
    group_chooser.expand
    group_chooser.select_row_by_name(restricted_group.name)
  end

  context "when moderator would lose access" do
    before { sign_in(moderator) }

    it "shows confirmation dialog on save" do
      remove_everyone_and_add_restricted_group
      category_page.save_settings

      expect(dialog).to be_open
      expect(dialog).to have_content(I18n.t("js.category.errors.self_lockout"))
    end

    it "saves and redirects home when confirmed" do
      remove_everyone_and_add_restricted_group
      category_page.save_settings
      dialog.click_yes

      expect(page).to have_current_path("/")
      expect(category.reload.category_groups.map(&:group_id)).to contain_exactly(
        restricted_group.id,
      )
    end

    it "does not save when cancelled" do
      remove_everyone_and_add_restricted_group
      category_page.save_settings
      dialog.click_no

      category_page.visit_security(category)
      expect(permission_row).to have_group_permission("everyone")
    end
  end

  context "when moderator belongs to the restricted group" do
    before do
      restricted_group.add(moderator)
      sign_in(moderator)
    end

    it "saves without showing dialog" do
      remove_everyone_and_add_restricted_group
      category_page.save_settings

      expect(dialog).to be_closed
      expect(category.reload.category_groups.map(&:group_id)).to contain_exactly(
        restricted_group.id,
      )
    end
  end
end
