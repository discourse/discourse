# frozen_string_literal: true

module DiscourseAi
  class PostImageDescriptionsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    def index
      post = find_post
      guardian.ensure_can_edit!(post)

      render json: {
               descriptions:
                 DiscourseAi::PostImageDescriptions.editable_descriptions(
                   post,
                   description_locale(post),
                 ),
             }
    end

    def update
      post = find_post
      guardian.ensure_can_edit!(post)

      description = params[:description].to_s.strip

      if description.blank?
        return(
          render_json_error(
            I18n.t("discourse_ai.post_image_descriptions.errors.description_blank"),
            status: :unprocessable_entity,
          )
        )
      end

      if description.length > DiscourseAi::PostImageDescriptions::MAX_DESCRIPTION_LENGTH
        return(
          render_json_error(
            I18n.t(
              "discourse_ai.post_image_descriptions.errors.description_too_long",
              count: DiscourseAi::PostImageDescriptions::MAX_DESCRIPTION_LENGTH,
            ),
            status: :unprocessable_entity,
          )
        )
      end

      image_description =
        DiscourseAi::PostImageDescriptions.update_description(
          post,
          description_locale(post),
          params[:base62_sha1],
          description,
        )

      raise Discourse::NotFound if image_description.blank?

      render json: {
               base62_sha1: image_description.base62_sha1,
               description: image_description.description,
             }
    end

    private

    def find_post
      Post.find(params[:post_id])
    end

    def description_locale(post)
      params[:locale].presence || DiscourseAi::PostImageDescriptions.original_locale(post)
    end
  end
end
