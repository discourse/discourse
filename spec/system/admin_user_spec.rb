# frozen_string_literal: true

describe "Admin User Page", type: :system do
  fab!(:current_user) { Fabricate(:admin) }

  let(:admin_user_page) { PageObjects::Pages::AdminUser.new }
  let(:suspend_user_modal) { PageObjects::Modals::PenalizeUser.new("suspend") }
  let(:silence_user_modal) { PageObjects::Modals::PenalizeUser.new("silence") }

  before { sign_in(current_user) }

  context "when visiting an admin's page" do
    fab!(:admin)

    before { admin_user_page.visit(admin) }

    it "doesn't display the suspend or silence buttons" do
      expect(admin_user_page).to have_no_suspend_button
      expect(admin_user_page).to have_no_silence_button
    end
  end

  context "when visiting a moderator's page" do
    fab!(:moderator)

    before { admin_user_page.visit(moderator) }

    it "doesn't display the suspend or silence buttons" do
      expect(admin_user_page).to have_no_suspend_button
      expect(admin_user_page).to have_no_silence_button
    end
  end

  context "when visting a regular user's page" do
    fab!(:user) { Fabricate(:user, ip_address: "93.123.44.90") }
    fab!(:similar_user) { Fabricate(:user, ip_address: user.ip_address) }
    fab!(:another_mod) { Fabricate(:moderator, ip_address: user.ip_address) }
    fab!(:another_admin) { Fabricate(:admin, ip_address: user.ip_address) }

    before { admin_user_page.visit(user) }

    it "displays the suspend and silence buttons" do
      expect(admin_user_page).to have_suspend_button
      expect(admin_user_page).to have_silence_button
    end

    it "displays username in the title" do
      expect(page).to have_css(".display-row.username")
      expect(page.title).to eq("#{user.username} - Admin - Discourse")
    end

    describe "the suspend user modal" do
      it "displays the list of users who share the same IP but are not mods or admins" do
        admin_user_page.click_suspend_button

        expect(suspend_user_modal.similar_users).to contain_exactly(similar_user.username)
        expect(admin_user_page.similar_users_warning).to include(
          I18n.t("admin_js.admin.user.other_matches", count: 1, username: user.username),
        )
      end
    end

    describe "the silence user modal" do
      it "displays the list of users who share the same IP but are not mods or admins" do
        admin_user_page.click_silence_button

        expect(silence_user_modal.similar_users).to contain_exactly(similar_user.username)
        expect(admin_user_page.similar_users_warning).to include(
          I18n.t("admin_js.admin.user.other_matches", count: 1, username: user.username),
        )
      end
    end
  end
end
