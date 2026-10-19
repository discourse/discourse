# frozen_string_literal: true

describe "Admin Fonts Page" do
  fab!(:admin)
  fab!(:image_upload)

  let(:fonts_page) { PageObjects::Pages::AdminFonts.new }
  let(:image_file) { file_from_fixtures("logo.png", "images") }
  let(:modal) { PageObjects::Modals::Base.new }

  before { sign_in(admin) }

  describe "fonts" do
    it "allows an admin to change the site's base font and heading font" do
      fonts_page.visit
      fonts_page.form.select_font("base", "helvetica")

      expect(fonts_page.form).to have_no_font("heading", "JetBrains Mono")
      fonts_page.form.show_more_fonts("heading")
      fonts_page.form.select_font("heading", "jet-brains-mono")

      fonts_page.form.submit
      expect(fonts_page.form).to have_saved_successfully

      expect(browser_root.locator("html").filter(visible: true).get_attribute("style")).to include(
        "font-family: Helvetica; --heading-font-family: JetBrains Mono",
      )

      fonts_page.visit
      expect(fonts_page.form.active_font("base")).to eq("Helvetica")

      fonts_page.visit
      expect(fonts_page.form.active_font("heading")).to eq("JetBrains Mono")
    end

    it "allows an admin to change default text size and does not update existing users preferences" do
      Jobs.run_immediately!
      fonts_page.visit
      expect(browser_root.locator("html.text-size-normal").filter(visible: true)).not_to have_count(
        0,
      )
      fonts_page.form.select_default_text_size("larger")

      fonts_page.form.submit
      expect(modal).to be_open
      expect(modal.header).to contain_text(
        browser_text_pattern(I18n.t("admin_js.admin.config.fonts.backfill_modal.title")),
        useInnerText: true,
      )
      modal.close
      expect(modal).to be_closed
      expect(fonts_page.form).to have_saved_successfully

      expect(browser_root.locator("html").filter(visible: true).get_attribute("class")).to include(
        "text-size-larger",
      )

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_root.locator("html.text-size-normal").filter(visible: true)).not_to have_count(
        0,
      )
    end

    it "allows an admin to change default text size and updates existing users preferences" do
      Jobs.run_immediately!
      fonts_page.visit
      expect(browser_root.locator("html.text-size-normal").filter(visible: true)).not_to have_count(
        0,
      )
      fonts_page.form.select_default_text_size("larger")

      fonts_page.form.submit
      expect(modal).to be_open
      expect(modal.header).to contain_text(
        browser_text_pattern(I18n.t("admin_js.admin.config.fonts.backfill_modal.title")),
        useInnerText: true,
      )
      modal.click_primary_button
      expect(modal).to be_closed
      expect(fonts_page.form).to have_saved_successfully

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_root.locator("html.text-size-larger").filter(visible: true)).not_to have_count(
        0,
      )
    end
  end
end
