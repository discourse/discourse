# frozen_string_literal: true

describe "Uploading files in the composer to S3" do
  fab!(:current_user, :admin)

  let(:modal) { PageObjects::Modals::Base.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic) { PageObjects::Pages::Topic.new }

  describe "direct S3 uploads" do
    describe "single part uploads" do
      it "uploads custom avatars to S3" do
        setup_or_skip_s3_system_test
        sign_in(current_user)

        browser_page
          .goto("/my/preferences/account")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        browser_root.locator("#edit-avatar").filter(visible: true).click
        browser_root.locator("#uploaded-avatar").filter(visible: true).click
        browser_root.locator(
          "input[type='file']:not(:disabled)[id=#{"custom-profile-upload".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"custom-profile-upload".to_s.to_json}]",
        ).set_input_files(File.absolute_path(file_from_fixtures("logo.jpg")))
        expect(
          browser_root.locator(".avatar-uploader .avatar-uploader__button[data-uploaded]").filter(
            visible: true,
          ),
        ).not_to have_count(0)
        modal.click_primary_button
        expect(modal).to be_closed
        expect(
          browser_root.locator("#user-avatar-uploads[data-custom-avatar-upload-id]").filter(
            visible: false,
          ),
        ).not_to have_count(0)
        expect(current_user.reload.uploaded_avatar_id).to eq(
          browser_root
            .locator("#user-avatar-uploads")
            .get_attribute("data-custom-avatar-upload-id")
            .to_i,
        )
      end
    end

    describe "multipart uploads" do
      it "uploads a file in the post composer" do
        setup_or_skip_s3_system_test
        sign_in(current_user)

        topic.open_new_topic

        file_path = file_from_fixtures("logo.png", "images").path
        browser_root.locator(
          "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
        ).set_input_files(file_path)

        expect(browser_root.locator("#file-uploading").filter(visible: true)).to have_count(0)
        expect(composer.preview.locator(".image-wrapper").filter(visible: true)).not_to have_count(
          0,
        )
      end
    end
  end
end
