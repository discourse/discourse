# frozen_string_literal: true

describe "Composer - ProseMirror - Uploads", native_playwright: true do
  include_context "with native prosemirror editor"

  let(:uploads) do
    PageObjects::Native::ComposerUploads.new(page: browser_page, editor: composer.rich_editor)
  end
  let(:slow_upload) { PageObjects::Native::SlowUpload.new(browser_page) }

  describe "image uploads" do
    it "shows the completed image without flashing or continuing to pulse" do
      open_composer

      file_path = file_from_fixtures("logo.png", "images").path
      uploads.attach(file_path)

      expect(composer.in_progress_uploads).to have_count(0)
      expect(composer.image_nodes.first).to be_visible
      expect(uploads.transparent_images).to have_count(0)
      composer.wait_for_images_to_stop_animating

      composer.type_content(" text after the image")
      composer.wait_for_images_to_stop_animating
    end

    it "produces correct markdown after upload completes" do
      open_composer

      file_path = file_from_fixtures("logo.png", "images").path
      uploads.attach(file_path)

      expect(composer.in_progress_uploads).to have_count(0)
      expect(composer.image_nodes.first).to be_visible

      composer.toggle_rich_editor
      expect(composer.markdown_editor).not_to have_value(/blob:/)
      expect(composer.markdown_editor).not_to have_value(/Uploading:/)
      expect(composer.markdown_editor).to have_value(%r{!\[.*\]\(upload://})
    end

    it "uploads multiple images at once" do
      open_composer

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      uploads.attach([file_path_1, file_path_2])

      expect(composer.in_progress_uploads).to have_count(0)
      expect(composer.image_nodes).to have_count(2)
      composer.wait_for_images_to_stop_animating
    end
  end

  describe "non-image uploads" do
    before { SiteSetting.authorized_extensions += "|pdf" }

    it "replaces the placeholder with a link after upload" do
      open_composer

      file_path = file_from_fixtures("small.pdf", "pdf").path
      uploads.attach(file_path)

      expect(composer.in_progress_uploads).to have_count(0)
      expect(uploads.file_placeholders).to have_count(0)
      expect(uploads.file_links.first).to be_visible
    end

    it "uploads mixed image and non-image files" do
      open_composer

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("small.pdf", "pdf").path
      uploads.attach([file_path_1, file_path_2])

      expect(composer.in_progress_uploads).to have_count(0)
      expect(composer.image_nodes).to have_count(1)
      expect(uploads.file_links.first).to be_visible
    end

    it "shows both placeholders simultaneously during mixed upload" do
      open_composer

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("large.pdf", "pdf").path
      slow_upload.during do
        uploads.attach([file_path_1, file_path_2])
        expect(composer.in_progress_uploads).to be_visible
        expect(uploads.image_placeholders.first).to be_visible
        expect(uploads.file_placeholders.first).to be_visible
      end
    end
  end

  describe "upload cancellation" do
    it "removes image placeholder when upload is cancelled" do
      open_composer

      file_path = file_from_fixtures("logo.png", "images").path
      slow_upload.during do
        uploads.attach(file_path)
        expect(composer.in_progress_uploads).to be_visible
        uploads.cancel_all.click

        expect(composer.in_progress_uploads).to have_count(0)
        expect(uploads.image_placeholders).to have_count(0)
      end
    end

    it "removes non-image placeholder when upload is cancelled" do
      SiteSetting.authorized_extensions += "|pdf"
      open_composer

      file_path = file_from_fixtures("large.pdf", "pdf").path
      slow_upload.during do
        uploads.attach(file_path)
        expect(composer.in_progress_uploads).to be_visible
        uploads.cancel_all.click

        expect(composer.in_progress_uploads).to have_count(0)
        expect(uploads.file_placeholders).to have_count(0)
      end
    end

    it "cancels individual non-image upload via inline cancel button" do
      SiteSetting.authorized_extensions += "|pdf"
      open_composer

      file_path = file_from_fixtures("large.pdf", "pdf").path
      slow_upload.during do
        uploads.attach(file_path)
        expect(uploads.file_placeholders.first).to be_visible

        uploads.cancel_file.click

        expect(uploads.file_placeholders).to have_count(0)
      end
    end

    it "cancels individual image upload via overlay cancel button" do
      open_composer

      file_path = file_from_fixtures("logo.png", "images").path
      slow_upload.during do
        uploads.attach(file_path)
        expect(uploads.image_overlay.first).to be_visible

        uploads.cancel_image.click

        expect(uploads.image_placeholders).to have_count(0)
      end
    end
  end

  describe "progress indicator" do
    it "shows progress overlay on image placeholder" do
      open_composer

      file_path = file_from_fixtures("logo.png", "images").path
      slow_upload.during do
        uploads.attach(file_path)
        expect(uploads.image_progress.first).to be_visible
      end
    end

    it "shows progress on non-image placeholder" do
      SiteSetting.authorized_extensions += "|pdf"
      open_composer

      file_path = file_from_fixtures("large.pdf", "pdf").path
      slow_upload.during do
        uploads.attach(file_path)
        expect(uploads.file_progress.first).to be_visible
      end
    end
  end
end
