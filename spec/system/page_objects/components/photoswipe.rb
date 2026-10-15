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
      QUOTE_BTN = ".pswp__button--quote-image"
      COUNTER = ".pswp__custom-counter"
      CAPTION = ".pswp__caption"
      CAPTION_TITLE = ".pswp__caption-title"
      CAPTION_DETAILS = ".pswp__caption-details"
      UI_VISIBLE = ".pswp--ui-visible"
      ACTIVE_IMG = ".pswp__item[aria-hidden='false'] .pswp__img"

      def initialize
        @component = browser_root.locator(SELECTOR).filter(visible: true)
      end

      def visible?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(SELECTOR).filter(visible: true),
        )
      end

      def hidden?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(SELECTOR).filter(visible: true),
        )
      end

      def next_button
        component.locator(NEXT_BTN).filter(visible: true)
      end

      def prev_button
        component.locator(PREV_BTN).filter(visible: true)
      end

      def image_info_button
        component.locator(IMAGE_INFO_BTN).filter(visible: true)
      end

      def quote_button
        component.locator(QUOTE_BTN).filter(visible: true)
      end

      def close_button
        component.locator(CLOSE_BTN).filter(visible: true)
      end

      def counter
        component.locator(COUNTER).filter(visible: true)
      end

      def has_counter?(text)
        PlaywrightMatchers.contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          component.locator(COUNTER).filter(visible: true),
        )
      end

      def has_no_counter?
        PlaywrightMatchers.have_count(0).matches?(
          component
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(COUNTER)
            .filter(visible: true),
        )
      end

      def has_caption_title?(caption)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(caption)],
          useInnerText: true,
        ).matches?(component.locator(CAPTION_TITLE).filter(visible: true))
      end

      def has_caption_details?(details)
        PlaywrightMatchers.have_css("opacity", "1").matches?(component.locator(CAPTION_DETAILS)) &&
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(details)],
            useInnerText: true,
          ).matches?(component.locator(CAPTION_DETAILS).filter(visible: true))
      end

      def has_no_caption?
        PlaywrightMatchers.have_count(0).matches?(
          component
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(CAPTION)
            .filter(visible: true),
        )
      end

      def has_no_caption_details?
        component.wait_for(state: "visible")
        details = component.locator(CAPTION_DETAILS)
        details.count.zero? || PlaywrightMatchers.have_css("opacity", "0").matches?(details)
      end

      def has_next_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          component.locator(NEXT_BTN).filter(visible: true),
        )
      end

      def has_no_next_button?
        PlaywrightMatchers.have_count(0).matches?(
          component
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(NEXT_BTN)
            .filter(visible: true),
        )
      end

      def has_prev_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          component.locator(PREV_BTN).filter(visible: true),
        )
      end

      def has_no_prev_button?
        PlaywrightMatchers.have_count(0).matches?(
          component
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(PREV_BTN)
            .filter(visible: true),
        )
      end

      def has_download_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          component.locator(DOWNLOAD_BTN).filter(visible: true),
        )
      end

      def has_no_download_button?
        PlaywrightMatchers.have_count(0).matches?(
          component
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(DOWNLOAD_BTN)
            .filter(visible: true),
        )
      end

      def has_original_image_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          component.locator(ORIGINAL_IMAGE_BTN).filter(visible: true),
        )
      end

      def has_no_original_image_button?
        PlaywrightMatchers.have_count(0).matches?(
          component
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(ORIGINAL_IMAGE_BTN)
            .filter(visible: true),
        )
      end

      def has_image_info_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          component.locator(IMAGE_INFO_BTN).filter(visible: true),
        )
      end

      def has_no_image_info_button?
        PlaywrightMatchers.have_count(0).matches?(
          component
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(IMAGE_INFO_BTN)
            .filter(visible: true),
        )
      end

      def has_quote_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          component.locator(QUOTE_BTN).filter(visible: true),
        )
      end

      def has_no_quote_button?
        PlaywrightMatchers.have_count(0).matches?(
          component
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(QUOTE_BTN)
            .filter(visible: true),
        )
      end

      def has_ui_visible?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(UI_VISIBLE).filter(visible: true),
        )
      end

      def has_no_ui_visible?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(UI_VISIBLE).filter(visible: true),
        )
      end

      def has_image_source?(upload)
        PlaywrightMatchers.have_count(0).does_not_match?(
          component.locator(ACTIVE_IMG + "[src$='#{upload.url}']").filter(visible: true),
        )
      end
    end
  end
end
