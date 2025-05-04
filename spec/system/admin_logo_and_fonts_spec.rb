# frozen_string_literal: true

describe "Admin Logo and Fonts Page", type: :system do
  fab!(:admin)
  fab!(:image_upload)

  let(:logo_and_fonts_page) { PageObjects::Pages::AdminLogoAndFonts.new }
  let(:image_file) { file_from_fixtures("logo.png", "images") }
  let(:modal) { PageObjects::Modals::Base.new }

  before { sign_in(admin) }

  describe "logo" do
    describe "primary section" do
      let(:primary_section_logos) do
        %i[logo logo_dark large_icon favicon logo_small logo_small_dark]
      end
      it "can upload images and dark versions" do
        logo_and_fonts_page.visit

        expect(logo_and_fonts_page.logo_form).to have_no_form_field(:logo_dark)
        logo_and_fonts_page.logo_form.toggle_dark_mode(:logo_dark_required)
        expect(logo_and_fonts_page.logo_form).to have_form_field(:logo_dark)

        expect(logo_and_fonts_page.logo_form).to have_no_form_field(:logo_small_dark)
        logo_and_fonts_page.logo_form.toggle_dark_mode(:logo_small_dark_required)
        expect(logo_and_fonts_page.logo_form).to have_form_field(:logo_small_dark)

        primary_section_logos.each do |image_type|
          logo_and_fonts_page.logo_form.upload_image(image_type, image_file)
        end

        primary_section_logos.each do |image_type|
          expect(logo_and_fonts_page.logo_form.image_uploader(image_type)).to have_uploaded_image
        end

        logo_and_fonts_page.logo_form.submit
        expect(logo_and_fonts_page.logo_form).to have_saved_successfully

        visit("/")
        logo_and_fonts_page.visit

        expect(logo_and_fonts_page.logo_form).to have_form_field(:logo_dark)
        expect(logo_and_fonts_page.logo_form).to have_form_field(:logo_small_dark)

        primary_section_logos.each do |image_type|
          expect(logo_and_fonts_page.logo_form.image_uploader(image_type)).to have_uploaded_image
        end
      end

      it "can remove images" do
        primary_section_logos.each { |image_type| SiteSetting.send("#{image_type}=", image_upload) }

        logo_and_fonts_page.visit

        primary_section_logos.each do |image_type|
          expect(logo_and_fonts_page.logo_form.image_uploader(image_type)).to have_uploaded_image
        end

        primary_section_logos.each do |image_type|
          logo_and_fonts_page.logo_form.remove_image(image_type)
        end

        logo_and_fonts_page.logo_form.submit
        expect(page).to have_css("#site-text-logo")

        primary_section_logos.each { |image_type| expect(SiteSetting.send(image_type)).to eq(nil) }
      end
    end

    describe "mobile section" do
      let(:mobile_section_logos) { %i[mobile_logo mobile_logo_dark manifest_icon apple_touch_icon] }
      it "can upload images and dark versions" do
        logo_and_fonts_page.visit
        logo_and_fonts_page.logo_form.expand_mobile_section

        expect(logo_and_fonts_page.logo_form).to have_no_form_field(:mobile_logo_dark)
        logo_and_fonts_page.logo_form.toggle_dark_mode(:mobile_logo_dark_required)
        expect(logo_and_fonts_page.logo_form).to have_form_field(:mobile_logo_dark)

        mobile_section_logos.each do |image_type|
          logo_and_fonts_page.logo_form.upload_image(image_type, image_file)
        end

        mobile_section_logos.each do |image_type|
          expect(logo_and_fonts_page.logo_form.image_uploader(image_type)).to have_uploaded_image
        end

        logo_and_fonts_page.logo_form.submit
        expect(logo_and_fonts_page.logo_form).to have_saved_successfully

        visit("/")
        logo_and_fonts_page.visit
        logo_and_fonts_page.logo_form.expand_mobile_section

        expect(logo_and_fonts_page.logo_form).to have_form_field(:mobile_logo_dark)

        mobile_section_logos.each do |image_type|
          expect(logo_and_fonts_page.logo_form.image_uploader(image_type)).to have_uploaded_image
        end
      end

      it "can remove images" do
        mobile_section_logos.each { |image_type| SiteSetting.send("#{image_type}=", image_upload) }

        logo_and_fonts_page.visit
        logo_and_fonts_page.logo_form.expand_mobile_section

        mobile_section_logos.each do |image_type|
          expect(logo_and_fonts_page.logo_form.image_uploader(image_type)).to have_uploaded_image
        end

        mobile_section_logos.each do |image_type|
          logo_and_fonts_page.logo_form.remove_image(image_type)
        end

        logo_and_fonts_page.logo_form.submit
        expect(logo_and_fonts_page.logo_form).to have_saved_successfully

        mobile_section_logos.each { |image_type| expect(SiteSetting.send(image_type)).to eq(nil) }
      end
    end

    describe "email section" do
      let(:email_section_logos) { %i[digest_logo] }
      it "can upload images" do
        logo_and_fonts_page.visit
        logo_and_fonts_page.logo_form.expand_email_section

        email_section_logos.each do |image_type|
          logo_and_fonts_page.logo_form.upload_image(image_type, image_file)
        end

        email_section_logos.each do |image_type|
          expect(logo_and_fonts_page.logo_form.image_uploader(image_type)).to have_uploaded_image
        end

        logo_and_fonts_page.logo_form.submit
        expect(logo_and_fonts_page.logo_form).to have_saved_successfully

        visit("/")
        logo_and_fonts_page.visit
        logo_and_fonts_page.logo_form.expand_email_section

        email_section_logos.each do |image_type|
          expect(logo_and_fonts_page.logo_form.image_uploader(image_type)).to have_uploaded_image
        end
      end

      it "can remove images" do
        email_section_logos.each { |image_type| SiteSetting.send("#{image_type}=", image_upload) }

        logo_and_fonts_page.visit
        logo_and_fonts_page.logo_form.expand_email_section

        email_section_logos.each do |image_type|
          expect(logo_and_fonts_page.logo_form.image_uploader(image_type)).to have_uploaded_image
        end

        email_section_logos.each do |image_type|
          logo_and_fonts_page.logo_form.remove_image(image_type)
        end

        logo_and_fonts_page.logo_form.submit
        expect(logo_and_fonts_page.logo_form).to have_saved_successfully

        email_section_logos.each { |image_type| expect(SiteSetting.send(image_type)).to eq(nil) }
      end
    end

    describe "social media section" do
      let(:social_media_section_logos) { %i[opengraph_image] }
      it "can upload images" do
        logo_and_fonts_page.visit
        logo_and_fonts_page.logo_form.expand_social_media_section

        social_media_section_logos.each do |image_type|
          logo_and_fonts_page.logo_form.upload_image(image_type, image_file)
        end

        social_media_section_logos.each do |image_type|
          expect(logo_and_fonts_page.logo_form.image_uploader(image_type)).to have_uploaded_image
        end

        logo_and_fonts_page.logo_form.submit
        expect(logo_and_fonts_page.logo_form).to have_saved_successfully

        visit("/")
        logo_and_fonts_page.visit
        logo_and_fonts_page.logo_form.expand_social_media_section

        social_media_section_logos.each do |image_type|
          expect(logo_and_fonts_page.logo_form.image_uploader(image_type)).to have_uploaded_image
        end
      end

      it "can remove images" do
        social_media_section_logos.each do |image_type|
          SiteSetting.send("#{image_type}=", image_upload)
        end

        logo_and_fonts_page.visit
        logo_and_fonts_page.logo_form.expand_social_media_section

        social_media_section_logos.each do |image_type|
          expect(logo_and_fonts_page.logo_form.image_uploader(image_type)).to have_uploaded_image
        end

        social_media_section_logos.each do |image_type|
          logo_and_fonts_page.logo_form.remove_image(image_type)
        end

        logo_and_fonts_page.logo_form.submit
        expect(logo_and_fonts_page.logo_form).to have_saved_successfully

        social_media_section_logos.each do |image_type|
          expect(SiteSetting.send(image_type)).to eq(nil)
        end
      end
    end
  end

  describe "fonts" do
    it "allows an admin to change the site's base font and heading font" do
      logo_and_fonts_page.visit
      logo_and_fonts_page.fonts_form.select_font("base", "helvetica")

      expect(logo_and_fonts_page.fonts_form).to have_no_font("heading", "JetBrains Mono")
      logo_and_fonts_page.fonts_form.show_more_fonts("heading")
      logo_and_fonts_page.fonts_form.select_font("heading", "jet-brains-mono")

      logo_and_fonts_page.fonts_form.submit
      expect(logo_and_fonts_page.fonts_form).to have_saved_successfully

      expect(page.find("html")["style"]).to include(
        "font-family: Helvetica; --heading-font-family: JetBrains Mono",
      )

      logo_and_fonts_page.visit
      expect(logo_and_fonts_page.fonts_form.active_font("base")).to eq("Helvetica")

      logo_and_fonts_page.visit
      expect(logo_and_fonts_page.fonts_form.active_font("heading")).to eq("JetBrains Mono")
    end

    it "allows an admin to change default text size and does not update existing users preferences" do
      Jobs.run_immediately!
      logo_and_fonts_page.visit
      expect(page).to have_css("html.text-size-normal")
      logo_and_fonts_page.fonts_form.select_default_text_size("larger")

      logo_and_fonts_page.fonts_form.submit
      expect(modal).to be_open
      expect(modal.header).to have_content(
        I18n.t("admin_js.admin.config.logo_and_fonts.fonts.backfill_modal.title"),
      )
      modal.close
      expect(modal).to be_closed
      expect(logo_and_fonts_page.fonts_form).to have_saved_successfully

      expect(page.find("html")["class"]).to include("text-size-larger")

      visit "/"
      expect(page).to have_css("html.text-size-normal")
    end

    it "allows an admin to change default text size and updates existing users preferences" do
      Jobs.run_immediately!
      logo_and_fonts_page.visit
      expect(page).to have_css("html.text-size-normal")
      logo_and_fonts_page.fonts_form.select_default_text_size("larger")

      logo_and_fonts_page.fonts_form.submit
      expect(modal).to be_open
      expect(modal.header).to have_content(
        I18n.t("admin_js.admin.config.logo_and_fonts.fonts.backfill_modal.title"),
      )
      modal.click_primary_button
      expect(modal).to be_closed
      expect(logo_and_fonts_page.fonts_form).to have_saved_successfully

      visit "/"
      expect(page).to have_css("html.text-size-larger")
    end
  end
end
