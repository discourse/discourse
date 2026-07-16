# frozen_string_literal: true

module PageObjects
  module Components
    class AiPostImageCaptions < PageObjects::Components::Base
      PREVIEW_EDITOR_BUTTON = ".d-editor-preview .ai-post-image-caption-editor__button"
      MODAL = ".ai-post-image-caption-editor-modal"

      def has_post_image_count?(post, count:)
        post_component(post).cooked_content.has_css?("img", count: count, visible: :all)
      end

      def has_image_caption?(post, image:, description:)
        post_component(post).cooked_content.has_xpath?(
          "(.//img)[#{image}][contains(@aria-description, #{xpath_literal(description)})]",
          visible: :all,
        )
      end

      def has_editor_button_count?(count:)
        has_css?(PREVIEW_EDITOR_BUTTON, count: count)
      end

      def edit_preview_image_caption(image:, description:)
        all(PREVIEW_EDITOR_BUTTON)[image - 1].click
        find("#{MODAL} textarea").fill_in(with: description)
        find("#{MODAL} .btn-primary").click
        has_no_css?(MODAL)
        self
      end

      private

      def post_component(post)
        PageObjects::Components::Post.new(post.post_number)
      end

      def xpath_literal(value)
        value = value.to_s

        return "'#{value}'" if !value.include?("'")
        return "\"#{value}\"" if !value.include?('"')

        "concat(#{value.split("'").map { |part| "'#{part}'" }.join(%{, "\"'\"", })})"
      end
    end
  end
end
