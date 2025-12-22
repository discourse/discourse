# frozen_string_literal: true

module PageObjects
  module Components
    class ImageGridCarousel < PageObjects::Components::Base
      def initialize(post_number)
        @post_number = post_number
      end

      def has_carousel?
        has_css?(carousel_selector)
      end

      def has_track?
        has_css?("#{carousel_selector} .d-image-grid__track")
      end

      def has_mode?(mode)
        has_css?("#{carousel_selector} .d-image-grid__carousel--#{mode}")
      end

      def has_slides?(count:)
        has_css?("#{carousel_selector} .d-image-grid__slide", count: count)
      end

      def has_active_slide?
        has_css?("#{carousel_selector} .d-image-grid__slide.is-active")
      end

      private

      def carousel_selector
        "#post_#{@post_number} .d-image-grid--carousel"
      end
    end
  end
end
