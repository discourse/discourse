# frozen_string_literal: true

module PageObjects
  module Components
    class ImageCarousel < PageObjects::Components::Base
      def initialize(post_number)
        @post_number = post_number
      end

      def has_carousel?
        have_count(0).does_not_match?(browser_root.locator(carousel_selector).filter(visible: true))
      end

      def has_track?
        have_count(0).does_not_match?(
          browser_root.locator("#{carousel_selector} .d-image-carousel__track").filter(
            visible: true,
          ),
        )
      end

      def has_mode?(mode)
        have_count(0).does_not_match?(
          browser_root.locator(
            "#{carousel_selector} .d-image-carousel.d-image-carousel--#{mode}",
          ).filter(visible: true),
        )
      end

      def has_slides?(count:)
        have_count(count).matches?(
          browser_root.locator("#{carousel_selector} .d-image-carousel__slide").filter(
            visible: true,
          ),
        )
      end

      def has_active_slide?
        have_count(0).does_not_match?(
          browser_root.locator("#{carousel_selector} .d-image-carousel__slide.is-active").filter(
            visible: true,
          ),
        )
      end

      def has_active_slide_index?(index)
        have_count(0).does_not_match?(
          browser_root.locator(
            "#{carousel_selector} .d-image-carousel__slide[data-index='#{index}'].is-active",
          ).filter(visible: true),
        )
      end

      def click_next
        browser_root
          .locator("#{carousel_selector} .d-image-carousel__nav--next")
          .filter(visible: true)
          .click
      end

      def click_prev
        browser_root
          .locator("#{carousel_selector} .d-image-carousel__nav--prev")
          .filter(visible: true)
          .click
      end

      def next_button_disabled?
        browser_root
          .locator("#{carousel_selector} .d-image-carousel__nav--next")
          .filter(visible: true)
          .disabled?
      end

      def prev_button_disabled?
        browser_root
          .locator("#{carousel_selector} .d-image-carousel__nav--prev")
          .filter(visible: true)
          .disabled?
      end

      def focus_track
        browser_root
          .locator("#{carousel_selector} .d-image-carousel__track")
          .filter(visible: true)
          .click
        self
      end

      private

      def carousel_selector
        "#post_#{@post_number} .d-image-grid--carousel"
      end
    end
  end
end
