# frozen_string_literal: true

describe "Cakeday/Birthday emojis", type: :system do
  CONTROL_DATE = Time.zone.local(2020, 6, 10)
  fab!(:current_user) { Fabricate(:admin, date_of_birth: CONTROL_DATE.prev_year(14)) }

  let(:user_page) { PageObjects::Pages::User.new }
  let(:user_menu) { PageObjects::Components::UserMenu.new }

  before { sign_in(current_user) }

  context "for users with `created_at` and `date_of_birth` dates" do
    fab!(:user_with_cakeday) { Fabricate(:user, created_at: CONTROL_DATE.prev_year) }

    it "correctly shows emojis in users' profiles" do
      page.driver.with_playwright_page do |pw_page|
        pw_page.clock.install(time: CONTROL_DATE)
      end

      user_page.visit(user_with_cakeday)

      expect(page).to have_current_path("/u/#{user_with_cakeday.username}/summary")
      expect(user_page).to have_css(".user-cakeday div[title=\"#{I18n.t('js.user.anniversary.title')}\"] .emoji[alt='cake']")

      user_menu.open.click_profile_tab
      find(".summary").click

      expect(page).to have_current_path("/u/#{current_user.username}/summary")
      expect(user_page).not_to have_css(".user-cakeday div[title=\"#{I18n.t('js.user.anniversary.title')}\"] .emoji[alt='cake']")
      expect(user_page).to have_css(".user-cakeday div[title=\"#{I18n.t('js.user.date_of_birth.user_title')}\"] .emoji[alt='birthday']")
    end
  end
end