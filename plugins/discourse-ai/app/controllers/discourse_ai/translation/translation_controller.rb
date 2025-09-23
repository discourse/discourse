# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TranslationController < ::ApplicationController
      requires_plugin DiscourseAi::PLUGIN_NAME

      before_action :ensure_logged_in
      before_action :check_permissions

      def translate
        post = Post.find_by(id: params[:post_id])
        raise ActiveRecord::RecordNotFound unless post

        if DiscourseAi::Translation.enabled?
          Jobs.enqueue(:detect_translate_post, post_id: post.id, force: true)
        else
          return(
            render json:
                     failed_json.merge(error: I18n.t("discourse_ai.translation.errors.disabled")),
                   status: 400
          )
        end

        render json: success_json
      end

      private

      def check_permissions
        if !current_user&.in_any_groups?(SiteSetting.content_localization_allowed_groups_map)
          raise Discourse::InvalidAccess
        end
      end
    end
  end
end
