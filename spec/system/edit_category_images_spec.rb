# frozen_string_literal: true

describe "Edit Category Images", type: :system do
  fab!(:admin)
  fab!(:category)
  fab!(:upload) { Fabricate(:upload, user: admin) }
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

        logo = file_from_fixtures("logo.png", "images").path

        find("#category-logo-uploader .image-upload-controls").click
        attach_file(
          "category-logo-uploader__input",
          "#{Rails.root}/spec/fixtures/images/logo.png",
          make_visible: true,
        )

        expect(page).to have_content("uploaded successfully").or have_css(
               ".uploaded-image-preview.input-xxlarge",
             )
      end
    end
  end
end
