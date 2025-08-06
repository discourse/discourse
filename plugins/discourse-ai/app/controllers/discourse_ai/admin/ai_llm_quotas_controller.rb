# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiLlmQuotasController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      def index
        quotas = LlmQuota.includes(:group)

        render json: {
                 quotas:
                   ActiveModel::ArraySerializer.new(quotas, each_serializer: LlmQuotaSerializer),
               }
      end

      def create
        quota = LlmQuota.new(quota_params)

        if quota.save
          render json: LlmQuotaSerializer.new(quota), status: :created
        else
          render_json_error quota
        end
      end

      def update
        quota = LlmQuota.find(params[:id])

        if quota.update(quota_params)
          render json: LlmQuotaSerializer.new(quota)
        else
          render_json_error quota
        end
      end

      def destroy
        quota = LlmQuota.find(params[:id])
        quota.destroy!

        head :no_content
      rescue ActiveRecord::RecordNotFound
        render json: { error: I18n.t("not_found") }, status: 404
      end

      private

      def quota_params
        params.require(:quota).permit(
          :group_id,
          :llm_model_id,
          :max_tokens,
          :max_usages,
          :duration_seconds,
        )
      end
    end
  end
end
