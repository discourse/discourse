# frozen_string_literal: true

describe "Edit Category Images" do
  fab!(:admin)
  fab!(:category)
  let(:category_page) { PageObjects::Pages::Category.new }

  context "when trying to upload an image" do
    before { sign_in(admin) }

    context "when authorized_extensions blank and authorized_extensions_for_staff have restrictions" do
      before do
        SiteSetting.authorized_extensions = ""
        SiteSetting.authorized_extensions_for_staff = "jpg|jpeg|png"
        SiteSetting.enable_s3_uploads = false
      end

      it "displays and updates new counter" do
        category_page.visit_images(category)

        browser_root
          .locator("#category-logo-uploader .file-uploader__controls")
          .filter(visible: true)
          .click
        browser_root.locator(
          "input[type='file']:not(:disabled)[id=#{"category-logo-uploader__input".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"category-logo-uploader__input".to_s.to_json}]",
        ).set_input_files("#{Rails.root.join("spec/fixtures/images/logo.png")}")

        try_until_success do
          success_message = browser_page.get_by_text("uploaded successfully").visible?
          uploaded_preview =
            browser_root.locator(".has-image .file-uploader__preview.input-xxlarge").visible?
          expect(success_message || uploaded_preview).to eq(true)
        end

        upload = Upload.last
        expect(upload.user_id).to eq(admin.id)
        expect(upload.original_filename).to eq("logo.png")
      end
    end
  end
end
