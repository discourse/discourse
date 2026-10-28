# frozen_string_literal: true

describe "Admin leaderboards" do
  fab!(:current_user, :admin)
  let(:admin_leaderboard_page) { PageObjects::Pages::AdminLeaderboards.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    SiteSetting.discourse_gamification_enabled = true
    sign_in(current_user)
  end

  it "can create a leaderboard" do
    visit("/admin/plugins/discourse-gamification")

    click_on(I18n.t("js.gamification.leaderboard.cta"))

    admin_leaderboard_page.new_form.field("name").fill_in("My leaderboard")
    admin_leaderboard_page.new_form.submit

    expect(page).to have_content(I18n.t("js.gamification.leaderboard.create_success"))
    expect(admin_leaderboard_page.full_form.field("name").value).to eq("My leaderboard")

    expect(page).to have_current_path(
      "/admin/plugins/discourse-gamification/leaderboards/#{DiscourseGamification::GamificationLeaderboard.last.id}/edit",
    )

    admin_leaderboard_page.full_form.field("from_date").fill_in(12.months.ago.end_of_month)
    admin_leaderboard_page.full_form.field("to_date").fill_in(11.months.ago.end_of_month)

    admin_leaderboard_page.select_included_groups("admins")
    admin_leaderboard_page.select_excluded_groups("trust_level_0")
    admin_leaderboard_page.full_form.submit

    expect(page).to have_content(I18n.t("js.gamification.leaderboard.save_success"))

    expect(DiscourseGamification::GamificationLeaderboard.last).to have_attributes(
      name: "My leaderboard",
      from_date: 12.months.ago.end_of_month.to_date,
      to_date: 11.months.ago.end_of_month.to_date,
      included_groups_ids: [Group::AUTO_GROUPS[:admins]],
      excluded_groups_ids: [Group::AUTO_GROUPS[:trust_level_0]],
    )
  end

  context "when there is an existing leaderboard" do
    fab!(:leaderboard) { Fabricate(:gamification_leaderboard, name: "Coolest duders") }

    it "can edit a leaderboard" do
      visit("/admin/plugins/discourse-gamification")

      admin_leaderboard_page.edit_leaderboard(leaderboard)
      admin_leaderboard_page.full_form.field("name").fill_in("Coolest dudettes")
      admin_leaderboard_page.full_form.submit

      expect(page).to have_content(I18n.t("js.gamification.leaderboard.save_success"))

      expect(leaderboard.reload.name).to eq("Coolest dudettes")
    end

    it "opens the edit page from the leaderboard name" do
      visit("/admin/plugins/discourse-gamification")

      admin_leaderboard_page.click_leaderboard_name(leaderboard)

      expect(page).to have_current_path(
        "/admin/plugins/discourse-gamification/leaderboards/#{leaderboard.id}/edit",
      )
      expect(admin_leaderboard_page.full_form.field("name").value).to eq("Coolest duders")
    end

    it "opens the public leaderboard from the row menu" do
      visit("/admin/plugins/discourse-gamification")

      admin_leaderboard_page.view_leaderboard(leaderboard)

      expect(page).to have_current_path("/leaderboard/#{leaderboard.id}")
    end

    it "loads the new and edit pages directly" do
      visit("/admin/plugins/discourse-gamification/leaderboards/new")
      expect(admin_leaderboard_page.new_form.field("name")).to be_present

      visit("/admin/plugins/discourse-gamification/leaderboards/#{leaderboard.id}/edit")
      expect(admin_leaderboard_page.full_form.field("name").value).to eq("Coolest duders")
    end

    it "redirects the old edit URL" do
      visit("/admin/plugins/discourse-gamification/leaderboards/#{leaderboard.id}")

      expect(page).to have_current_path(
        "/admin/plugins/discourse-gamification/leaderboards/#{leaderboard.id}/edit",
      )
    end

    it "keeps score overrides when saving with the scoring section collapsed" do
      leaderboard.update!(score_overrides: { "like_given" => 5 })

      visit("/admin/plugins/discourse-gamification/leaderboards/#{leaderboard.id}/edit")
      admin_leaderboard_page.full_form.field("name").fill_in("Coolest dudettes")
      admin_leaderboard_page.full_form.submit

      expect(page).to have_content(I18n.t("js.gamification.leaderboard.save_success"))
      expect(leaderboard.reload.score_overrides).to eq({ "like_given" => 5 })
    end

    it "shows the creator and opens their user card" do
      creator = User.find(leaderboard.created_by_id)
      user_card = PageObjects::Components::UserCard.new

      visit("/admin/plugins/discourse-gamification")

      expect(page).to have_css(
        "#leaderboard-admin__row-#{leaderboard.id} .leaderboard-admin__creator-link",
        text: creator.username,
      )

      admin_leaderboard_page.click_creator(leaderboard)
      expect(user_card).to be_showing_user(creator.username)
    end

    it "can delete a leaderboard" do
      visit("/admin/plugins/discourse-gamification")

      admin_leaderboard_page.delete_leaderboard(leaderboard)
      expect(page).to have_content(I18n.t("js.gamification.leaderboard.confirm_destroy"))

      dialog.click_danger
      expect(page).to have_content(I18n.t("js.gamification.leaderboard.delete_success"))

      expect(DiscourseGamification::GamificationLeaderboard.exists?(leaderboard.id)).to eq(false)
    end
  end
end
