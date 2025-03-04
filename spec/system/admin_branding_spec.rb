# frozen_string_literal: true

describe "Admin Branding Page", type: :system do
  fab!(:admin)
  fab!(:image_upload)

  let(:branding_page) { PageObjects::Pages::AdminBranding.new }
  let(:image_file) { file_from_fixtures("logo.png", "images") }

  before { sign_in(admin) }

  describe "primary section" do
    let(:primary_section_logos) { %i[logo logo_dark large_icon favicon logo_small logo_small_dark] }
    it "can upload images and dark versions" do
      branding_page.visit

      expect(branding_page.logo_form).to have_no_form_field(:logo_dark)
      branding_page.logo_form.toggle_dark_mode(:logo_dark_required)
      expect(branding_page.logo_form).to have_form_field(:logo_dark)

      expect(branding_page.logo_form).to have_no_form_field(:logo_small_dark)
      branding_page.logo_form.toggle_dark_mode(:logo_small_dark_required)
      expect(branding_page.logo_form).to have_form_field(:logo_small_dark)

      primary_section_logos.each do |image_type|
        branding_page.logo_form.upload_image(image_type, image_file)
      end

      primary_section_logos.each do |image_type|
        expect(branding_page.logo_form.image_uploader(image_type)).to have_uploaded_image
      end

      branding_page.logo_form.submit
      expect(branding_page.logo_form).to have_saved_successfully

      visit("/")
      branding_page.visit

      expect(branding_page.logo_form).to have_form_field(:logo_dark)
      expect(branding_page.logo_form).to have_form_field(:logo_small_dark)

      primary_section_logos.each do |image_type|
        expect(branding_page.logo_form.image_uploader(image_type)).to have_uploaded_image
      end
    end

    it "can remove images" do
      primary_section_logos.each { |image_type| SiteSetting.send("#{image_type}=", image_upload) }

      branding_page.visit

      primary_section_logos.each do |image_type|
        expect(branding_page.logo_form.image_uploader(image_type)).to have_uploaded_image
      end

      primary_section_logos.each { |image_type| branding_page.logo_form.remove_image(image_type) }

      branding_page.logo_form.submit
      expect(branding_page.logo_form).to have_saved_successfully

      primary_section_logos.each { |image_type| expect(SiteSetting.send(image_type)).to eq(nil) }
    end
  end

  describe "mobile section" do
    let(:mobile_section_logos) { %i[mobile_logo mobile_logo_dark manifest_icon apple_touch_icon] }
    it "can upload images and dark versions" do
      branding_page.visit
      branding_page.logo_form.expand_mobile_section

      expect(branding_page.logo_form).to have_no_form_field(:mobile_logo_dark)
      branding_page.logo_form.toggle_dark_mode(:mobile_logo_dark_required)
      expect(branding_page.logo_form).to have_form_field(:mobile_logo_dark)

      mobile_section_logos.each do |image_type|
        branding_page.logo_form.upload_image(image_type, image_file)
      end

      mobile_section_logos.each do |image_type|
        expect(branding_page.logo_form.image_uploader(image_type)).to have_uploaded_image
      end

      branding_page.logo_form.submit
      expect(branding_page.logo_form).to have_saved_successfully

      visit("/")
      branding_page.visit
      branding_page.logo_form.expand_mobile_section

      expect(branding_page.logo_form).to have_form_field(:mobile_logo_dark)

      mobile_section_logos.each do |image_type|
        expect(branding_page.logo_form.image_uploader(image_type)).to have_uploaded_image
      end
    end

    it "can remove images" do
      mobile_section_logos.each { |image_type| SiteSetting.send("#{image_type}=", image_upload) }

      branding_page.visit
      branding_page.logo_form.expand_mobile_section

      mobile_section_logos.each do |image_type|
        expect(branding_page.logo_form.image_uploader(image_type)).to have_uploaded_image
      end

      mobile_section_logos.each { |image_type| branding_page.logo_form.remove_image(image_type) }

      branding_page.logo_form.submit
      expect(branding_page.logo_form).to have_saved_successfully

      mobile_section_logos.each { |image_type| expect(SiteSetting.send(image_type)).to eq(nil) }
    end
  end

  describe "email section" do
    let(:email_section_logos) { %i[digest_logo] }
    it "can upload images" do
      branding_page.visit
      branding_page.logo_form.expand_email_section

      email_section_logos.each do |image_type|
        branding_page.logo_form.upload_image(image_type, image_file)
      end

      email_section_logos.each do |image_type|
        expect(branding_page.logo_form.image_uploader(image_type)).to have_uploaded_image
      end

      branding_page.logo_form.submit
      expect(branding_page.logo_form).to have_saved_successfully

      visit("/")
      branding_page.visit
      branding_page.logo_form.expand_email_section

      email_section_logos.each do |image_type|
        expect(branding_page.logo_form.image_uploader(image_type)).to have_uploaded_image
      end
    end

    it "can remove images" do
      email_section_logos.each { |image_type| SiteSetting.send("#{image_type}=", image_upload) }

      branding_page.visit
      branding_page.logo_form.expand_email_section

      email_section_logos.each do |image_type|
        expect(branding_page.logo_form.image_uploader(image_type)).to have_uploaded_image
      end

      email_section_logos.each { |image_type| branding_page.logo_form.remove_image(image_type) }

      branding_page.logo_form.submit
      expect(branding_page.logo_form).to have_saved_successfully

      email_section_logos.each { |image_type| expect(SiteSetting.send(image_type)).to eq(nil) }
    end
  end

  describe "social media section" do
    let(:social_media_section_logos) { %i[opengraph_image] }
    it "can upload images" do
      branding_page.visit
      branding_page.logo_form.expand_social_media_section

      social_media_section_logos.each do |image_type|
        branding_page.logo_form.upload_image(image_type, image_file)
      end

      social_media_section_logos.each do |image_type|
        expect(branding_page.logo_form.image_uploader(image_type)).to have_uploaded_image
      end

      branding_page.logo_form.submit
      expect(branding_page.logo_form).to have_saved_successfully

      visit("/")
      branding_page.visit
      branding_page.logo_form.expand_social_media_section

      social_media_section_logos.each do |image_type|
        expect(branding_page.logo_form.image_uploader(image_type)).to have_uploaded_image
      end
    end

    it "can remove images" do
      social_media_section_logos.each do |image_type|
        SiteSetting.send("#{image_type}=", image_upload)
      end

      branding_page.visit
      branding_page.logo_form.expand_social_media_section

      social_media_section_logos.each do |image_type|
        expect(branding_page.logo_form.image_uploader(image_type)).to have_uploaded_image
      end

      social_media_section_logos.each do |image_type|
        branding_page.logo_form.remove_image(image_type)
      end

      branding_page.logo_form.submit
      expect(branding_page.logo_form).to have_saved_successfully

      social_media_section_logos.each do |image_type|
        expect(SiteSetting.send(image_type)).to eq(nil)
      end
    end
  end
end
