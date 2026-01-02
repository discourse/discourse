# frozen_string_literal: true

module PageObjects
  module Components
    class ImageCarousel < PageObjects::Components::Base
      def initialize(post_number)
        @post_number = post_number
      end

      def has_carousel?
        has_css?(carousel_selector)
      end

      def has_track?
        has_css?("#{carousel_selector} .d-image-carousel__track")
      end

      def has_mode?(mode)
        has_css?("#{carousel_selector} .d-image-carousel.--#{mode}")
      end

      def has_slides?(count:)
        has_css?("#{carousel_selector} .d-image-carousel__slide", count: count)
      end

      def has_active_slide?
        has_css?("#{carousel_selector} .d-image-carousel__slide.is-active")
      end

      def has_active_slide_index?(index)
        has_css?("#{carousel_selector} .d-image-carousel__slide[data-index='#{index}'].is-active")
      end

      def click_next
        find("#{carousel_selector} .d-image-carousel__nav--next").click
      end

      def click_prev
        find("#{carousel_selector} .d-image-carousel__nav--prev").click
      end

      def next_button_disabled?
        find("#{carousel_selector} .d-image-carousel__nav--next").disabled?
      end

      def prev_button_disabled?
        find("#{carousel_selector} .d-image-carousel__nav--prev").disabled?
      end

      def focus_track
        find("#{carousel_selector} .d-image-carousel__track").click
        self
      end

      private

      def carousel_selector
        "#post_#{@post_number} .d-image-grid--carousel"
      end
    end
  end
end
