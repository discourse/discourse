# frozen_string_literal: true

module DiscourseAi
  class PostImageCaptionsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    def index
      post = find_post
      locale = caption_locale(post)
      ensure_can_edit_caption!(post, locale)

      render json: { captions: DiscourseAi::PostImageCaptions.editable_captions(post, locale) }
    end

    def update
      post = find_post
      locale = caption_locale(post)
      ensure_can_edit_caption!(post, locale)

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
          locale,
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

    def ensure_can_edit_caption!(post, locale)
      if locale == DiscourseAi::PostImageCaptions.original_locale(post)
        guardian.ensure_can_edit!(post)
      else
        guardian.ensure_can_localize_post!(post)
      end
    end

    def caption_locale(post)
      locale = params[:locale]
      raise Discourse::InvalidAccess unless locale.nil? || locale.is_a?(String)

      locale.presence || DiscourseAi::PostImageCaptions.original_locale(post)
    end
  end
end
