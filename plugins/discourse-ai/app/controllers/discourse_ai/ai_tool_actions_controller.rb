# frozen_string_literal: true

module DiscourseAi
  class AiToolActionsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    def revert
      reviewable = ReviewableAiToolAction.find_by(id: params[:reviewable_id])
      raise Discourse::NotFound if reviewable.blank?

      result = reviewable.revert!(current_user)
      if result[:status] != "success"
        return(
          render_json_error(
            result[:error] || I18n.t("discourse_ai.ai_bot.tool_revert.errors.failed"),
          )
        )
      end

      render json: success_json.merge(message: result[:message])
    end
  end
end
