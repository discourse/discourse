# frozen_string_literal: true

module PageObjects
  module Components
    class PhotoSwipe < PageObjects::Components::Base
      attr_reader :component

      SELECTOR = ".pswp"
      CLOSE_BTN = ".pswp__button--close"
      ZOOM_BTN = ".pswp__button--zoom"
      NEXT_BTN = ".pswp__button--arrow--next"
      PREV_BTN = ".pswp__button--arrow--prev"
      DOWNLOAD_BTN = ".pswp__button--download-image"
      ORIGINAL_IMAGE_BTN = ".pswp__button--original-image"
      IMAGE_INFO_BTN = ".pswp__button--image-info"
      COUNTER = ".pswp__counter"
      CAPTION = ".pswp__caption"
      CAPTION_TITLE = ".pswp__caption-title"
      CAPTION_DETAILS = ".pswp__caption-details"
      UI_VISIBLE = ".pswp--ui-visible"

      def initialize
        @component = find(SELECTOR)
      end

      def visible?
        page.has_css?(SELECTOR)
      end

      def hidden?
        page.has_no_css?(SELECTOR)
      end

      def next_button
        component.find(NEXT_BTN)
      end

      def prev_button
        component.find(PREV_BTN)
      end

      def image_info_button
        component.find(IMAGE_INFO_BTN)
      end

      def close_button
        component.find(CLOSE_BTN)
      end

      def has_counter?(text)
        component.has_css?(COUNTER, text: text)
      end

      def has_no_counter?
        component.has_no_css?(COUNTER)
      end

      def has_caption_title?(caption)
        component.has_css?(CAPTION_TITLE, text: caption)
      end

      def has_caption_details?(details)
        component.has_css?(CAPTION_DETAILS, text: details)
      end

      def has_no_caption?
        component.has_no_css?(CAPTION)
      end

      def has_no_caption_details?
        component.has_no_css?(CAPTION_DETAILS)
      end

      def has_next_button?
        component.has_css?(NEXT_BTN)
      end

      def has_no_next_button?
        component.has_no_css?(NEXT_BTN)
      end

      def has_prev_button?
        component.has_css?(PREV_BTN)
      end

      def has_no_prev_button?
        component.has_no_css?(PREV_BTN)
      end

      def has_download_button?
        component.has_css?(DOWNLOAD_BTN)
      end

      def has_no_download_button?
        component.has_no_css?(DOWNLOAD_BTN)
      end

      def has_original_image_button?
        component.has_css?(ORIGINAL_IMAGE_BTN)
      end

      def has_no_original_image_button?
        component.has_no_css?(ORIGINAL_IMAGE_BTN)
      end

      def has_image_info_button?
        component.has_css?(IMAGE_INFO_BTN)
      end

      def has_ui_visible?
        page.has_css?(UI_VISIBLE)
      end

      def has_no_ui_visible?
        page.has_no_css?(UI_VISIBLE)
      end
    end
  end
end
