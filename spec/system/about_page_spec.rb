# frozen_string_literal: true

describe "About page", type: :system do
  fab!(:image_upload)
  fab!(:admin) { Fabricate(:admin, last_seen_at: 1.hour.ago) }
  fab!(:moderator) { Fabricate(:moderator, last_seen_at: 1.hour.ago) }

  before do
    SiteSetting.title = "title for my forum"
    SiteSetting.site_description = "short description for my forum"
    SiteSetting.extended_site_description = <<~TEXT
      Somewhat lengthy description for my **forum**. [Some link](https://discourse.org). A list:
        1. One
        2. Two
      Last line.
    TEXT
    SiteSetting.extended_site_description_cooked =
      PrettyText.markdown(SiteSetting.extended_site_description)
    SiteSetting.about_banner_image = image_upload
    SiteSetting.contact_url = "http://some-contact-url.discourse.org"
  end

  let(:about_page) { PageObjects::Pages::About.new }

  it "renders successfully" do
    about_page.visit

    expect(about_page).to have_banner_image(image_upload)
    expect(about_page).to have_header_title(SiteSetting.title)
    expect(about_page).to have_short_description(SiteSetting.site_description)

    expect(about_page).to have_members_count(3, "3")
    expect(about_page).to have_admins_count(1, "1")
    expect(about_page).to have_moderators_count(1, "1")
  end

  it "doesn't render banner image when it's not set" do
    SiteSetting.about_banner_image = nil

    about_page.visit
    expect(about_page).to have_no_banner_image
  end

  describe "displayed site age" do
    it "says less than 1 month if the site is less than 1 month old" do
      Discourse.stubs(:site_creation_date).returns(1.week.ago)

      about_page.visit

      expect(about_page).to have_site_created_less_than_1_month_ago
    end

    it "says how many months old the site is if the site is less than 1 year old" do
      Discourse.stubs(:site_creation_date).returns(2.months.ago)

      about_page.visit

      expect(about_page).to have_site_created_in_months_ago(2)
    end

    it "says how many years old the site is if the site is more than 1 year old" do
      Discourse.stubs(:site_creation_date).returns(5.years.ago)

      about_page.visit

      expect(about_page).to have_site_created_in_years_ago(5)
    end
  end

  describe "the site activity section" do
    describe "topics" do
      before do
        Fabricate(:topic, created_at: 2.days.ago)
        Fabricate(:topic, created_at: 3.days.ago)
        Fabricate(:topic, created_at: 8.days.ago)
      end

      it "shows the count of topics created in the last 7 days" do
        about_page.visit
        expect(about_page.site_activities.topics).to have_count(2, "2")
        expect(about_page.site_activities.topics).to have_7_days_period
      end
    end

    describe "posts" do
      before do
        Fabricate(:post, created_at: 2.days.ago)
        Fabricate(:post, created_at: 1.hour.ago)
        Fabricate(:post, created_at: 3.hours.ago)
        Fabricate(:post, created_at: 23.hours.ago)
      end

      it "shows the count of topics created in the last day" do
        about_page.visit
        expect(about_page.site_activities.posts).to have_count(3, "3")
        expect(about_page.site_activities.posts).to have_1_day_period
      end
    end

    describe "visitors" do
      context "when the display_eu_visitor_stats setting is disabled" do
        before { SiteSetting.display_eu_visitor_stats = false }

        it "doesn't show the row" do
          about_page.visit

          expect(about_page.site_activities).to have_no_activity_item("visitors")
        end
      end

      context "when the display_eu_visitor_stats setting is enabled" do
        before { SiteSetting.display_eu_visitor_stats = true }

        it "shows the row" do
          about_page.visit

          expect(about_page.site_activities).to have_activity_item("visitors")
          expect(about_page.site_activities.visitors).to have_text(
            "0 visitors, about 0 from the EU",
          )
        end
      end
    end

    describe "active users" do
      before do
        User.update_all(last_seen_at: 1.month.ago)

        Fabricate(:user, last_seen_at: 1.hour.ago)
        Fabricate(:user, last_seen_at: 1.day.ago)
        Fabricate(:user, last_seen_at: 3.days.ago)
        Fabricate(:user, last_seen_at: 6.days.ago)
        Fabricate(:user, last_seen_at: 8.days.ago)
      end

      it "shows the count of active users in the last 7 days" do
        about_page.visit
        expect(about_page.site_activities.active_users).to have_count(4, "4") # 4 fabricated above
        expect(about_page.site_activities.active_users).to have_7_days_period
      end
    end

    describe "sign ups" do
      before do
        User.update_all(created_at: 1.month.ago)

        Fabricate(:user, created_at: 3.hours.ago)
        Fabricate(:user, created_at: 3.days.ago)
        Fabricate(:user, created_at: 8.days.ago)
      end

      it "shows the count of signups in the last 7 days" do
        about_page.visit
        expect(about_page.site_activities.sign_ups).to have_count(2, "2")
        expect(about_page.site_activities.sign_ups).to have_7_days_period
      end
    end

    describe "likes" do
      before do
        UserAction.destroy_all

        Fabricate(:user_action, created_at: 1.hour.ago, action_type: UserAction::LIKE)
        Fabricate(:user_action, created_at: 1.day.ago, action_type: UserAction::LIKE)
        Fabricate(:user_action, created_at: 1.month.ago, action_type: UserAction::LIKE)
        Fabricate(:user_action, created_at: 10.years.ago, action_type: UserAction::LIKE)
      end

      it "shows the count of likes of all time" do
        about_page.visit
        expect(about_page.site_activities.likes).to have_count(4, "4")
        expect(about_page.site_activities.likes).to have_all_time_period
      end
    end

    describe "traffic info footer" do
      it "is displayed when the display_eu_visitor_stats setting is true" do
        SiteSetting.display_eu_visitor_stats = true

        about_page.visit

        expect(about_page).to have_traffic_info_footer
      end

      it "is not displayed when the display_eu_visitor_stats setting is false" do
        SiteSetting.display_eu_visitor_stats = false

        about_page.visit

        expect(about_page).to have_no_traffic_info_footer
      end
    end
  end

  describe "our admins section" do
    before { User.update_all(last_seen_at: 1.month.ago) }

    fab!(:admins) { Fabricate.times(8, :admin) }

    it "displays only the 6 most recently seen admins when there are more than 6 admins" do
      admins[0].update!(last_seen_at: 4.minutes.ago)
      admins[1].update!(last_seen_at: 1.minutes.ago)
      admins[2].update!(last_seen_at: 10.minutes.ago)

      about_page.visit
      expect(about_page.admins_list).to have_expand_button

      displayed_admins = about_page.admins_list.users
      expect(displayed_admins.size).to eq(6)
      expect(displayed_admins.map { |u| u[:username] }.first(3)).to eq(
        [admins[1].username, admins[0].username, admins[2].username],
      )
    end

    it "allows expanding and collapsing the list of admins" do
      about_page.visit

      displayed_admins = about_page.admins_list.users
      expect(displayed_admins.size).to eq(6)

      expect(about_page.admins_list).to be_expandable

      about_page.admins_list.expand

      expect(about_page.admins_list).to be_collapsible

      displayed_admins = about_page.admins_list.users
      expect(displayed_admins.size).to eq(9) # 8 fabricated for this spec group and 1 global

      about_page.admins_list.collapse

      expect(about_page.admins_list).to be_expandable

      displayed_admins = about_page.admins_list.users
      expect(displayed_admins.size).to eq(6)
    end

    it "doesn't show an expand/collapse button when there are fewer than 6 admins" do
      User.where(id: admins.first(4).map(&:id)).destroy_all

      about_page.visit

      displayed_admins = about_page.admins_list.users
      expect(displayed_admins.size).to eq(5)
      expect(about_page.admins_list).to have_no_expand_button
    end

    it "prioritizes names when prioritize_username_in_ux is false" do
      SiteSetting.prioritize_username_in_ux = false

      about_page.visit

      displayed_admins = about_page.admins_list.users
      admins = User.where(username: displayed_admins.map { |u| u[:username] })
      expect(displayed_admins.map { |u| u[:displayed_username] }).to contain_exactly(
        *admins.pluck(:name),
      )
      expect(displayed_admins.map { |u| u[:displayed_name] }).to contain_exactly(
        *admins.pluck(:username),
      )
    end

    it "prioritizes usernames when prioritize_username_in_ux is true" do
      SiteSetting.prioritize_username_in_ux = true

      about_page.visit

      displayed_admins = about_page.admins_list.users
      admins = User.where(username: displayed_admins.map { |u| u[:username] })
      expect(displayed_admins.map { |u| u[:displayed_username] }).to contain_exactly(
        *admins.pluck(:username),
      )
      expect(displayed_admins.map { |u| u[:displayed_name] }).to contain_exactly(
        *admins.pluck(:name),
      )
    end

    it "opens the user card when a user is clicked" do
      about_page.visit

      about_page.admins_list.users.first[:node].click
      expect(about_page).to have_css("#user-card")
    end
  end

  describe "our moderators section" do
    before { User.update_all(last_seen_at: 1.month.ago) }

    fab!(:moderators) { Fabricate.times(9, :moderator) }

    it "displays only the 6 most recently seen moderators when there are more than 6 moderators" do
      moderators[5].update!(last_seen_at: 5.hours.ago)
      moderators[4].update!(last_seen_at: 2.hours.ago)
      moderators[1].update!(last_seen_at: 13.hours.ago)

      about_page.visit
      expect(about_page.moderators_list).to have_expand_button

      displayed_mods = about_page.moderators_list.users
      expect(displayed_mods.size).to eq(6)
      expect(displayed_mods.map { |u| u[:username] }.first(3)).to eq(
        [moderators[4].username, moderators[5].username, moderators[1].username],
      )
    end

    it "allows expanding and collapsing the list of moderators" do
      about_page.visit

      displayed_mods = about_page.moderators_list.users
      expect(displayed_mods.size).to eq(6)

      expect(about_page.moderators_list).to be_expandable

      about_page.moderators_list.expand

      expect(about_page.moderators_list).to be_collapsible

      displayed_mods = about_page.moderators_list.users
      expect(displayed_mods.size).to eq(10) # 9 fabricated for this spec group and 1 global

      about_page.moderators_list.collapse

      expect(about_page.moderators_list).to be_expandable

      displayed_mods = about_page.moderators_list.users
      expect(displayed_mods.size).to eq(6)
    end

    it "doesn't show an expand/collapse button when there are fewer than 6 moderators" do
      User.where(id: moderators.first(4).map(&:id)).destroy_all

      about_page.visit

      displayed_mods = about_page.moderators_list.users
      expect(displayed_mods.size).to eq(6)
      expect(about_page.moderators_list).to have_no_expand_button
    end

    it "prioritizes names when prioritize_username_in_ux is false" do
      SiteSetting.prioritize_username_in_ux = false

      about_page.visit

      displayed_mods = about_page.moderators_list.users
      moderators = User.where(username: displayed_mods.map { |u| u[:username] })
      expect(displayed_mods.map { |u| u[:displayed_username] }).to contain_exactly(
        *moderators.pluck(:name),
      )
      expect(displayed_mods.map { |u| u[:displayed_name] }).to contain_exactly(
        *moderators.pluck(:username),
      )
    end

    it "prioritizes usernames when prioritize_username_in_ux is true" do
      SiteSetting.prioritize_username_in_ux = true

      about_page.visit

      displayed_mods = about_page.moderators_list.users
      moderators = User.where(username: displayed_mods.map { |u| u[:username] })
      expect(displayed_mods.map { |u| u[:displayed_username] }).to contain_exactly(
        *moderators.pluck(:username),
      )
      expect(displayed_mods.map { |u| u[:displayed_name] }).to contain_exactly(
        *moderators.pluck(:name),
      )
    end

    it "opens the user card when a user is clicked" do
      about_page.visit

      about_page.moderators_list.users.last[:node].click
      expect(about_page).to have_css("#user-card")
    end
  end

  describe "the edit link" do
    it "appears for admins" do
      sign_in(admin)

      about_page.visit
      expect(about_page).to have_edit_link

      about_page.edit_link.click

      try_until_success { expect(current_url).to end_with("/admin/config/about") }
    end

    it "doesn't appear for moderators" do
      sign_in(moderator)

      about_page.visit
      expect(about_page).to have_no_edit_link
    end

    it "doesn't appear for normal users" do
      about_page.visit
      expect(about_page).to have_no_edit_link
    end
  end
end
