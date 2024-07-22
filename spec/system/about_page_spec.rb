# frozen_string_literal: true

describe "About page", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group, users: [current_user]) }
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

  describe "legacy version" do
    it "renders successfully for a logged-in user" do
      sign_in(current_user)

      visit("/about")

      expect(page).to have_css(".about.admins")
      expect(page).to have_css(".about.moderators")
      expect(page).to have_css(".about.stats")
      expect(page).to have_css(".about.contact")
    end

    it "renders successfully for an anonymous user" do
      visit("/about")

      expect(page).to have_css(".about.admins")
      expect(page).to have_css(".about.moderators")
      expect(page).to have_css(".about.stats")
      expect(page).to have_css(".about.contact")
    end
  end

  describe "redesigned version" do
    let(:about_page) { PageObjects::Pages::About.new }

    before do
      SiteSetting.experimental_redesigned_about_page_groups = group.id.to_s
      sign_in(current_user)
    end

    it "renders successfully for a logged in user" do
      about_page.visit

      expect(about_page).to have_banner_image(image_upload)
      expect(about_page).to have_header_title(SiteSetting.title)
      expect(about_page).to have_short_description(SiteSetting.site_description)

      expect(about_page).to have_members_count(4, "4")
      expect(about_page).to have_admins_count(1, "1")
      expect(about_page).to have_moderators_count(1, "1")
    end
  end
end
