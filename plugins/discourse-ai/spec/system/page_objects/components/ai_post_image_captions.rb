# frozen_string_literal: true

module PageObjects
  module Components
    class AiPostImageCaptions < PageObjects::Components::Base
      COMPOSER = PageObjects::Components::Composer::COMPOSER_ID
      MARKDOWN_PREVIEW = "#{COMPOSER} .d-editor-preview-wrapper .d-editor-preview"
      TRANSLATION_PREVIEW = "#{COMPOSER} .d-editor-translation-preview-content .d-editor-preview"
      RICH_IMAGE = "#{COMPOSER} .composer-image-node"
      ALT_TEXT_CONTROL = "#{RICH_IMAGE} .image-alt-text-input__display"
      CAPTION_DIALOG_TRIGGER = "[aria-haspopup=dialog]"
      MODAL = ".image-descriptions-modal"

      def has_post_image_count?(post, count:)
        post_component(post).cooked_content.has_css?("img", count: count, visible: :all)
      end

      def has_image_caption?(post, image:, description:)
        post_component(post).cooked_content.has_xpath?(
          "(#{XPath.descendant(:img)})[#{image}][#{XPath.attr(:"aria-description").contains(description)}]",
          visible: :all,
        )
      end

      def has_post_image_with_alt?(post, alt:)
        post_component(post).cooked_content.has_xpath?(image_with_alt(XPath, alt))
      end

      def has_preview_caption_buttons?(count:, translated: false)
        preview = translated ? TRANSLATION_PREVIEW : MARKDOWN_PREVIEW
        has_css?("#{preview} .alt-text-edit-btn#{CAPTION_DIALOG_TRIGGER}", count: count)
      end

      def edit_preview_image_caption(alt:, description:, translated: false)
        open_preview_image_descriptions(alt:, translated:)
        fill_in_description(description)
        apply_descriptions
      end

      def select_rich_image(alt:, upload:)
        # Resolving an upload placeholder can replace the image and clear its selection.
        find(
          :xpath,
          image_with_alt(XPath.css(RICH_IMAGE), alt)[XPath.attr(:src) == upload.url],
        ).click
      end

      def has_rich_image?(alt:, scale: nil)
        has_xpath?(image_with_alt(XPath.css(RICH_IMAGE), alt, scale:))
      end

      def has_rich_image_toolbar?
        has_css?("#{RICH_IMAGE} .composer-image-toolbar__zoom-in") &&
          has_css?("#{RICH_IMAGE} .composer-image-toolbar__trash")
      end

      def zoom_out_rich_image
        find("#{RICH_IMAGE} .composer-image-toolbar__zoom-out").click
      end

      def open_rich_image_descriptions(alt:)
        find("#{ALT_TEXT_CONTROL}#{CAPTION_DIALOG_TRIGGER}", exact_text: alt).click
      end

      def has_original_rich_image_controls?(alt:)
        has_css?("#{RICH_IMAGE} .composer-image-toolbar__zoom-out") &&
          has_css?("#{ALT_TEXT_CONTROL}:not(#{CAPTION_DIALOG_TRIGGER})", exact_text: alt) &&
          has_no_css?("#{ALT_TEXT_CONTROL}#{CAPTION_DIALOG_TRIGGER}")
      end

      def has_original_preview_alt_text_controls?(count:)
        has_css?(
          "#{MARKDOWN_PREVIEW} .alt-text-edit-btn:not(#{CAPTION_DIALOG_TRIGGER})",
          count: count,
        ) && has_no_css?("#{MARKDOWN_PREVIEW} .alt-text-edit-btn#{CAPTION_DIALOG_TRIGGER}")
      end

      def has_preview_image_controls?(alt:)
        image = preview_image_wrapper(alt:)
        image.has_css?(".alt-text-edit-btn .d-icon-pencil") &&
          image.has_css?(".alt-text", exact_text: alt) && image.has_css?(".scale-btn", count: 3) &&
          image.has_css?(".delete-image-button")
      end

      def open_preview_image_descriptions(alt:, translated: false)
        preview_image_wrapper(alt:, translated:).find(
          ".alt-text-edit-btn#{CAPTION_DIALOG_TRIGGER}",
        ).click
      end

      def resize_preview_image(alt:, scale:)
        preview_image_wrapper(alt:).find(".scale-btn[data-scale='#{scale}']").click
      end

      def remove_preview_image(alt:)
        preview_image_wrapper(alt:).find(".delete-image-button").click
      end

      def has_preview_image?(alt:, scale: nil)
        has_xpath?(image_with_alt(XPath.css(MARKDOWN_PREVIEW), alt, scale:))
      end

      def has_no_preview_image?(alt:)
        has_no_xpath?(image_with_alt(XPath.css(MARKDOWN_PREVIEW), alt))
      end

      def has_descriptions?(alt: nil, description:)
        within(MODAL) do
          (alt.nil? || has_field?("alt", with: alt)) && has_field?("description", with: description)
        end
      end

      def has_pending_description?
        within(MODAL) do
          has_text?(I18n.t("js.discourse_ai.post_image_captions.image_descriptions.pending")) &&
            has_no_field?("description")
        end
      end

      def fill_in_description(description)
        within(MODAL) { fill_in("description", with: description) }
      end

      def fill_in_alt_text(alt)
        within(MODAL) { fill_in("alt", with: alt) }
      end

      def apply_descriptions
        within(MODAL) { click_button(type: "submit") }
        expect(page).to have_no_css(MODAL)
      end

      def cancel_descriptions
        within(MODAL) { click_button(class: "d-modal-cancel") }
        expect(page).to have_no_css(MODAL)
      end

      private

      def image_with_alt(scope, alt, scale: nil)
        image = scope.descendant(:img)[XPath.attr(:alt) == alt]
        scale ? image[XPath.attr(:"data-scale") == scale.to_s] : image
      end

      def preview_image_wrapper(alt:, translated: false)
        preview = translated ? TRANSLATION_PREVIEW : MARKDOWN_PREVIEW
        find(:xpath, image_with_alt(XPath.css("#{preview} .image-wrapper"), alt).parent)
      end

      def post_component(post)
        PageObjects::Components::Post.new(post.post_number)
      end
    end
  end
end
