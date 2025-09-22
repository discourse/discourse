# frozen_string_literal: true

describe "Admin About Config Area Page", type: :system do
  fab!(:admin)
  fab!(:image_upload)

  let(:config_area) { PageObjects::Pages::AdminAboutConfigArea.new }

  let!(:extra_group_1) { Fabricate(:group, name: "extra1") }
  let!(:extra_group_2) { Fabricate(:group, name: "extra2") }
  let!(:extra_group_3) { Fabricate(:group, name: "extra3") }

  before { sign_in(admin) }

  context "when all fields have existing values" do
    before do
      SiteSetting.title = "my forums title"
      SiteSetting.site_description = "this is a description for my forums"
      SiteSetting.about_banner_image = image_upload
      SiteSetting.extended_site_description = "this is an extended description for my forums"
      SiteSetting.short_site_description = "short description for browser tab"

      SiteSetting.community_owner = "kitty"
      SiteSetting.contact_email = "kitty@litterbox.com"
      SiteSetting.contact_url = "https://hello.com"
      SiteSetting.site_contact_username = admin.username
      SiteSetting.site_contact_group_name = admin.groups.first.name

      SiteSetting.company_name = "kitty company inc."
      SiteSetting.governing_law = "kitty jurisdiction"
      SiteSetting.city_for_disputes = "no disputes allowed"

      SiteSetting.about_page_extra_groups = "#{extra_group_1.id}|#{extra_group_2.id}"
      SiteSetting.about_page_extra_groups_initial_members = 5
      SiteSetting.about_page_extra_groups_order = "order of creation"
      SiteSetting.about_page_extra_groups_show_description = true
    end

    it "populates all input fields correctly" do
      config_area.visit

      expect(config_area.general_settings_section.community_name_input.value).to eq(
        "my forums title",
      )
      expect(config_area.general_settings_section.community_summary_input.value).to eq(
        "this is a description for my forums",
      )
      expect(config_area.general_settings_section.community_description_editor.value).to eq(
        "this is an extended description for my forums",
      )
      expect(config_area.general_settings_section.community_title_input.value).to eq(
        "short description for browser tab",
      )
      expect(config_area.general_settings_section.banner_image_uploader).to have_uploaded_image

      expect(config_area.contact_information_section.community_owner_input.value).to eq("kitty")
      expect(config_area.contact_information_section.contact_email_input.value).to eq(
        "kitty@litterbox.com",
      )
      expect(config_area.contact_information_section.contact_url_input.value).to eq(
        "https://hello.com",
      )
      expect(
        config_area.contact_information_section.site_contact_user_selector,
      ).to have_selected_value(admin.username)
      expect(
        config_area.contact_information_section.site_contact_group_selector,
      ).to have_selected_value(admin.groups.first.id)

      expect(config_area.your_organization_section.company_name_input.value).to eq(
        "kitty company inc.",
      )
      expect(config_area.your_organization_section.governing_law_input.value).to eq(
        "kitty jurisdiction",
      )
      expect(config_area.your_organization_section.city_for_disputes_input.value).to eq(
        "no disputes allowed",
      )

      expect(config_area.group_listing_section.groups_input.value).to eq(
        "#{extra_group_1.id},#{extra_group_2.id}",
      )
      expect(config_area.group_listing_section.initial_members_input.value).to eq("5")
      expect(config_area.group_listing_section.order_input.value).to eq("order of creation")
      expect(config_area.group_listing_section.show_description_input.value).to eq(true)
    end
  end

  describe "the general settings card" do
    it "can saves its fields to their corresponding site settings" do
      config_area.visit

      image_file = file_from_fixtures("logo.png", "images")
      config_area.general_settings_section.community_name_input.fill_in("my community name")
      config_area.general_settings_section.community_summary_input.fill_in(
        "here's a bit of a summary",
      )
      config_area.general_settings_section.community_description_editor.fill_in(
        "here's an extended description for the **community**",
      )
      config_area.general_settings_section.community_title_input.fill_in(
        "here's a title for my site",
      )
      config_area.general_settings_section.banner_image_uploader.select_image(image_file.path)
      expect(config_area.general_settings_section.banner_image_uploader).to have_uploaded_image

      config_area.general_settings_section.banner_image_uploader.toggle_lightbox_preview
      expect(config_area.general_settings_section.banner_image_uploader).to have_lightbox_preview
      config_area.general_settings_section.banner_image_uploader.close_lightbox_preview

      config_area.general_settings_section.submit

      expect(config_area.general_settings_section).to have_saved_successfully

      expect(SiteSetting.title).to eq("my community name")
      expect(SiteSetting.site_description).to eq("here's a bit of a summary")
      expect(SiteSetting.extended_site_description).to eq(
        "here's an extended description for the **community**",
      )
      expect(SiteSetting.extended_site_description_cooked).to eq(
        "<p>here’s an extended description for the <strong>community</strong></p>",
      )
      expect(SiteSetting.short_site_description).to eq("here's a title for my site")
      expect(SiteSetting.about_banner_image.sha1).to eq(Upload.generate_digest(image_file))
    end

    describe "the banner image field" do
      it "can remove the uploaded image" do
        SiteSetting.about_banner_image = image_upload

        config_area.visit

        config_area.general_settings_section.banner_image_uploader.remove_image

        config_area.general_settings_section.submit
        expect(config_area.general_settings_section).to have_saved_successfully

        try_until_success { expect(SiteSetting.about_banner_image).to eq(nil) }
      end

      it "can upload an image using keyboard nav" do
        config_area.visit

        image_file = file_from_fixtures("logo.png", "images")
        config_area.general_settings_section.banner_image_uploader.select_image_with_keyboard(
          image_file.path,
        )

        expect(config_area.general_settings_section.banner_image_uploader).to have_uploaded_image
      end

      xit "can remove the uploaded image using keyboard nav" do
        SiteSetting.about_banner_image = image_upload

        config_area.visit

        config_area.general_settings_section.banner_image_uploader.remove_image_with_keyboard

        config_area.general_settings_section.submit
        expect(config_area.general_settings_section).to have_saved_successfully

        try_until_success { expect(SiteSetting.about_banner_image).to eq(nil) }
      end

      context "when login_required is true" do
        before { SiteSetting.login_required = true }

        it "doesn't mark the banner image upload as secure" do
          setup_or_skip_s3_system_test(enable_secure_uploads: true)

          config_area.visit

          image_file = file_from_fixtures("logo.png", "images")
          config_area.general_settings_section.banner_image_uploader.select_image(image_file.path)
          expect(config_area.general_settings_section.banner_image_uploader).to have_uploaded_image

          config_area.general_settings_section.submit

          expect(config_area.general_settings_section).to have_saved_successfully

          expect(SiteSetting.about_banner_image.secure).to eq(false)
        end
      end
    end
  end

  describe "the contact information card" do
    it "can saves its fields to their corresponding site settings" do
      config_area.visit

      config_area.contact_information_section.community_owner_input.fill_in("awesome owner")
      config_area.contact_information_section.contact_email_input.fill_in("owneremail@owner.com")
      config_area.contact_information_section.contact_url_input.fill_in(
        "https://website.owner.com/blah",
      )

      user_select_kit = config_area.contact_information_section.site_contact_user_selector
      user_select_kit.expand
      user_select_kit.search(admin.username)
      user_select_kit.select_row_by_value(admin.username)
      user_select_kit.collapse

      group_select_kit = config_area.contact_information_section.site_contact_group_selector
      group = admin.groups.first
      group_select_kit.expand
      group_select_kit.search(group.name)
      group_select_kit.select_row_by_value(group.id)
      group_select_kit.collapse

      config_area.contact_information_section.submit
      expect(config_area.contact_information_section).to have_saved_successfully

      expect(SiteSetting.community_owner).to eq("awesome owner")
      expect(SiteSetting.contact_email).to eq("owneremail@owner.com")
      expect(SiteSetting.contact_url).to eq("https://website.owner.com/blah")
      expect(SiteSetting.site_contact_username).to eq(admin.username)
      expect(SiteSetting.site_contact_group_name).to eq(group.name)
    end
  end

  describe "the your organization card" do
    it "can saves its fields to their corresponding site settings" do
      config_area.visit

      config_area.your_organization_section.company_name_input.fill_in("lil' company")
      config_area.your_organization_section.governing_law_input.fill_in("wild west law")
      config_area.your_organization_section.city_for_disputes_input.fill_in("teeb el shouq")

      config_area.your_organization_section.submit
      expect(config_area.your_organization_section).to have_saved_successfully

      expect(SiteSetting.company_name).to eq("lil' company")
      expect(SiteSetting.governing_law).to eq("wild west law")
      expect(SiteSetting.city_for_disputes).to eq("teeb el shouq")
    end
  end

  describe "the group listing card" do
    it "can saves its fields to their corresponding site settings" do
      config_area.visit

      config_area.group_listing_section.groups_input.select("extra3")
      config_area.group_listing_section.initial_members_input.fill_in("3")
      config_area.group_listing_section.order_input.select("alphabetically")
      config_area.group_listing_section.show_description_input.uncheck

      config_area.group_listing_section.submit
      expect(config_area.group_listing_section).to have_saved_successfully

      expect(SiteSetting.about_page_extra_groups).to include(extra_group_3.id.to_s)
      expect(SiteSetting.about_page_extra_groups_initial_members).to eq(3)
      expect(SiteSetting.about_page_extra_groups_order).to eq("alphabetically")
      expect(SiteSetting.about_page_extra_groups_show_description).to eq(false)
    end
  end
end
