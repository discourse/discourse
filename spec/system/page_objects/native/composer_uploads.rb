# frozen_string_literal: true
module PageObjects
  module Native
    class ComposerUploads
      def initialize(page:, editor:)
        @page = page
        @editor = editor
      end

      def attach(files)
        @page.locator("#file-uploader").set_input_files(files, timeout: 30_000)
      end

      def file_links
        @editor.locator("a[href]:visible")
      end

      def file_placeholders
        @editor.locator(".upload-placeholder.--file:visible")
      end

      def image_placeholders
        @editor.locator(".upload-placeholder.--image:visible")
      end

      def image_overlay
        @editor.locator(".upload-placeholder__overlay:visible")
      end

      def image_progress
        @editor.locator(".upload-placeholder__overlay .upload-placeholder__progress:visible")
      end

      def file_progress
        @editor.locator(".upload-placeholder.--file .upload-placeholder__progress:visible")
      end

      def cancel_all
        @page.locator("#cancel-file-upload:visible")
      end

      def cancel_file
        @page.locator(".upload-placeholder__cancel:visible")
      end

      def cancel_image
        @page.locator(".upload-placeholder__overlay .upload-placeholder__cancel:visible")
      end

      def content_images
        @editor.locator("img:not(.ProseMirror-separator):visible")
      end

      def transparent_images
        @editor.locator("img[src*='transparent.png']:visible")
      end
    end
  end
end
