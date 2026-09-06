# frozen_string_literal: true

module DiscourseAi
  class PostImageCaptionsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    def index
      post = find_post
      guardian.ensure_can_edit!(post)

      render json: {
               captions:
                 DiscourseAi::PostImageCaptions.editable_captions(post, caption_locale(post)),
             }
    end

    def update
      post = find_post
      guardian.ensure_can_edit!(post)

      description = params[:description].to_s.strip

      if description.blank?
        return(
          render_json_error(
            I18n.t("discourse_ai.post_image_captions.errors.description_blank"),
            status: :unprocessable_entity,
          )
        )
      end

      if description.length > DiscourseAi::PostImageCaptions::MAX_CAPTION_LENGTH
        return(
          render_json_error(
            I18n.t(
              "discourse_ai.post_image_captions.errors.description_too_long",
              count: DiscourseAi::PostImageCaptions::MAX_CAPTION_LENGTH,
            ),
            status: :unprocessable_entity,
          )
        )
      end

      image_caption =
        DiscourseAi::PostImageCaptions.update_caption(
          post,
          caption_locale(post),
          params[:base62_sha1],
          description,
        )

      raise Discourse::NotFound if image_caption.blank?

      render json: {
               base62_sha1: image_caption.base62_sha1,
               description: image_caption.description,
             }
    end

    private

    def find_post
      Post.find(params[:post_id])
    end

    def caption_locale(post)
      params[:locale].presence || DiscourseAi::PostImageCaptions.original_locale(post)
    end
  end
end
