# frozen_string_literal: true

describe "Admin Logo Page", type: :system do
  fab!(:admin)
  fab!(:image_upload)

  let(:logo_page) { PageObjects::Pages::AdminLogo.new }
  let(:image_file) { file_from_fixtures("logo.png", "images") }
  let(:modal) { PageObjects::Modals::Base.new }

  before { sign_in(admin) }

  describe "primary section" do
    let(:primary_section_logos) { %i[logo logo_dark large_icon favicon logo_small logo_small_dark] }
    it "can upload images and dark versions" do
      logo_page.visit

      expect(logo_page.form).to have_no_form_field(:logo_dark)
      logo_page.form.toggle_dark_mode(:logo_dark_required)
      expect(logo_page.form).to have_form_field(:logo_dark)

      expect(logo_page.form).to have_no_form_field(:logo_small_dark)
      logo_page.form.toggle_dark_mode(:logo_small_dark_required)
      expect(logo_page.form).to have_form_field(:logo_small_dark)

      primary_section_logos.each do |image_type|
        logo_page.form.upload_image(image_type, image_file)
      end

      primary_section_logos.each do |image_type|
        expect(logo_page.form.image_uploader(image_type)).to have_uploaded_image
      end

      logo_page.form.submit
      expect(logo_page.form).to have_saved_successfully

      visit("/")
      logo_page.visit

      expect(logo_page.form).to have_form_field(:logo_dark)
      expect(logo_page.form).to have_form_field(:logo_small_dark)

      primary_section_logos.each do |image_type|
        expect(logo_page.form.image_uploader(image_type)).to have_uploaded_image
      end
    end

    it "can remove images" do
      primary_section_logos.each { |image_type| SiteSetting.send("#{image_type}=", image_upload) }

      logo_page.visit

      primary_section_logos.each do |image_type|
        expect(logo_page.form.image_uploader(image_type)).to have_uploaded_image
      end

      primary_section_logos.each { |image_type| logo_page.form.remove_image(image_type) }

      logo_page.form.submit

      try_until_success do
        primary_section_logos.each { |image_type| expect(SiteSetting.send(image_type)).to eq(nil) }
      end
    end
  end

  describe "mobile section" do
    let(:mobile_section_logos) { %i[mobile_logo mobile_logo_dark manifest_icon apple_touch_icon] }
    it "can upload images and dark versions" do
      logo_page.visit
      logo_page.form.expand_mobile_section

      expect(logo_page.form).to have_no_form_field(:mobile_logo_dark)
      logo_page.form.toggle_dark_mode(:mobile_logo_dark_required)
      expect(logo_page.form).to have_form_field(:mobile_logo_dark)

      mobile_section_logos.each { |image_type| logo_page.form.upload_image(image_type, image_file) }

      mobile_section_logos.each do |image_type|
        expect(logo_page.form.image_uploader(image_type)).to have_uploaded_image
      end

      logo_page.form.submit
      expect(logo_page.form).to have_saved_successfully

      visit("/")
      logo_page.visit
      logo_page.form.expand_mobile_section

      expect(logo_page.form).to have_form_field(:mobile_logo_dark)

      mobile_section_logos.each do |image_type|
        expect(logo_page.form.image_uploader(image_type)).to have_uploaded_image
      end
    end

    it "can remove images" do
      mobile_section_logos.each { |image_type| SiteSetting.send("#{image_type}=", image_upload) }

      logo_page.visit
      logo_page.form.expand_mobile_section

      mobile_section_logos.each do |image_type|
        expect(logo_page.form.image_uploader(image_type)).to have_uploaded_image
      end

      mobile_section_logos.each { |image_type| logo_page.form.remove_image(image_type) }

      logo_page.form.submit
      expect(logo_page.form).to have_saved_successfully

      mobile_section_logos.each { |image_type| expect(SiteSetting.send(image_type)).to eq(nil) }
    end
  end

  describe "email section" do
    let(:email_section_logos) { %i[digest_logo] }
    it "can upload images" do
      logo_page.visit
      logo_page.form.expand_email_section

      email_section_logos.each { |image_type| logo_page.form.upload_image(image_type, image_file) }

      email_section_logos.each do |image_type|
        expect(logo_page.form.image_uploader(image_type)).to have_uploaded_image
      end

      logo_page.form.submit
      expect(logo_page.form).to have_saved_successfully

      visit("/")
      logo_page.visit
      logo_page.form.expand_email_section

      email_section_logos.each do |image_type|
        expect(logo_page.form.image_uploader(image_type)).to have_uploaded_image
      end
    end

    it "can remove images" do
      email_section_logos.each { |image_type| SiteSetting.send("#{image_type}=", image_upload) }

      logo_page.visit
      logo_page.form.expand_email_section

      email_section_logos.each do |image_type|
        expect(logo_page.form.image_uploader(image_type)).to have_uploaded_image
      end

      email_section_logos.each { |image_type| logo_page.form.remove_image(image_type) }

      logo_page.form.submit
      expect(logo_page.form).to have_saved_successfully

      email_section_logos.each { |image_type| expect(SiteSetting.send(image_type)).to eq(nil) }
    end
  end

  describe "social media section" do
    let(:social_media_section_logos) { %i[opengraph_image] }
    it "can upload images" do
      logo_page.visit
      logo_page.form.expand_social_media_section

      social_media_section_logos.each do |image_type|
        logo_page.form.upload_image(image_type, image_file)
      end

      social_media_section_logos.each do |image_type|
        expect(logo_page.form.image_uploader(image_type)).to have_uploaded_image
      end

      logo_page.form.submit
      expect(logo_page.form).to have_saved_successfully

      visit("/")
      logo_page.visit
      logo_page.form.expand_social_media_section

      social_media_section_logos.each do |image_type|
        expect(logo_page.form.image_uploader(image_type)).to have_uploaded_image
      end
    end

    it "can remove images" do
      social_media_section_logos.each do |image_type|
        SiteSetting.send("#{image_type}=", image_upload)
      end

      logo_page.visit
      logo_page.form.expand_social_media_section

      social_media_section_logos.each do |image_type|
        expect(logo_page.form.image_uploader(image_type)).to have_uploaded_image
      end

      social_media_section_logos.each { |image_type| logo_page.form.remove_image(image_type) }

      logo_page.form.submit
      expect(logo_page.form).to have_saved_successfully

      social_media_section_logos.each do |image_type|
        expect(SiteSetting.send(image_type)).to eq(nil)
      end
    end
  end
end
