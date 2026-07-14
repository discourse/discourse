# frozen_string_literal: true

describe "Composer - ProseMirror - Uploads" do
  include_context "with prosemirror editor"

  describe "image uploads" do
    it "replaces the placeholder with the uploaded image without a transparent.png flash" do
      open_composer

      file_path = file_from_fixtures("logo.png", "images").path
      attach_file("file-uploader", file_path, make_visible: true)

      expect(composer).to have_no_in_progress_uploads
      expect(rich).to have_css(".composer-image-node img")
      expect(rich).to have_no_css("img[src*='transparent.png']")
    end

    it "produces correct markdown after upload completes" do
      open_composer

      file_path = file_from_fixtures("logo.png", "images").path
      attach_file("file-uploader", file_path, make_visible: true)

      expect(composer).to have_no_in_progress_uploads
      expect(rich).to have_css(".composer-image-node img")

      composer.toggle_rich_editor
      expect(composer.composer_input.value).not_to include("blob:")
      expect(composer.composer_input.value).not_to include("Uploading:")
      expect(composer.composer_input.value).to match(%r{!\[.*\]\(upload://})
    end

    it "uploads multiple images at once" do
      open_composer

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      attach_file("file-uploader", [file_path_1, file_path_2], make_visible: true)

      expect(composer).to have_no_in_progress_uploads
      expect(rich).to have_css(".composer-image-node img", count: 2)
    end
  end

  describe "non-image uploads" do
    before { SiteSetting.authorized_extensions += "|pdf" }

    it "replaces the placeholder with a link after upload" do
      open_composer

      file_path = file_from_fixtures("small.pdf", "pdf").path
      attach_file("file-uploader", file_path, make_visible: true)

      expect(composer).to have_no_in_progress_uploads
      expect(rich).to have_no_css(".upload-placeholder.--file")
      expect(rich).to have_css("a[href]")
    end

    it "uploads mixed image and non-image files" do
      open_composer

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("small.pdf", "pdf").path
      attach_file("file-uploader", [file_path_1, file_path_2], make_visible: true)

      expect(composer).to have_no_in_progress_uploads
      expect(rich).to have_css(".composer-image-node img", count: 1)
      expect(rich).to have_css("a[href]")
    end

    it "shows both placeholders simultaneously during mixed upload" do
      open_composer

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("large.pdf", "pdf").path
      cdp.with_slow_upload do
        attach_file("file-uploader", [file_path_1, file_path_2], make_visible: true)
        expect(composer).to have_in_progress_uploads
        expect(rich).to have_css(".upload-placeholder.--image")
        expect(rich).to have_css(".upload-placeholder.--file")
      end
    end
  end

  describe "upload cancellation" do
    it "removes image placeholder when upload is cancelled" do
      open_composer

      file_path = file_from_fixtures("logo.png", "images").path
      cdp.with_slow_upload do
        attach_file("file-uploader", file_path, make_visible: true)
        expect(composer).to have_in_progress_uploads
        find("#cancel-file-upload").click

        expect(composer).to have_no_in_progress_uploads
        expect(rich).to have_no_css(".upload-placeholder.--image")
      end
    end

    it "removes non-image placeholder when upload is cancelled" do
      SiteSetting.authorized_extensions += "|pdf"
      open_composer

      file_path = file_from_fixtures("large.pdf", "pdf").path
      cdp.with_slow_upload do
        attach_file("file-uploader", file_path, make_visible: true)
        expect(composer).to have_in_progress_uploads
        find("#cancel-file-upload").click

        expect(composer).to have_no_in_progress_uploads
        expect(rich).to have_no_css(".upload-placeholder.--file")
      end
    end

    it "cancels individual non-image upload via inline cancel button" do
      SiteSetting.authorized_extensions += "|pdf"
      open_composer

      file_path = file_from_fixtures("large.pdf", "pdf").path
      cdp.with_slow_upload do
        attach_file("file-uploader", file_path, make_visible: true)
        expect(rich).to have_css(".upload-placeholder.--file")

        find(".upload-placeholder__cancel").click

        expect(rich).to have_no_css(".upload-placeholder.--file")
      end
    end

    it "cancels individual image upload via overlay cancel button" do
      open_composer

      file_path = file_from_fixtures("logo.png", "images").path
      cdp.with_slow_upload do
        attach_file("file-uploader", file_path, make_visible: true)
        expect(rich).to have_css(".upload-placeholder__overlay")

        find(".upload-placeholder__overlay .upload-placeholder__cancel").click

        expect(rich).to have_no_css(".upload-placeholder.--image")
      end
    end
  end

  describe "progress indicator" do
    it "shows progress overlay on image placeholder" do
      open_composer

      file_path = file_from_fixtures("logo.png", "images").path
      cdp.with_slow_upload do
        attach_file("file-uploader", file_path, make_visible: true)
        expect(rich).to have_css(".upload-placeholder__overlay .upload-placeholder__progress")
      end
    end

    it "shows progress on non-image placeholder" do
      SiteSetting.authorized_extensions += "|pdf"
      open_composer

      file_path = file_from_fixtures("large.pdf", "pdf").path
      cdp.with_slow_upload do
        attach_file("file-uploader", file_path, make_visible: true)
        expect(rich).to have_css(".upload-placeholder.--file .upload-placeholder__progress")
      end
    end
  end
end
