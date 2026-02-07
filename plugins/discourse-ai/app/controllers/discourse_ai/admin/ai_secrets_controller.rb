# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiSecretsController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      def index
        secrets = AiSecret.all.includes(:llm_models, :embedding_definitions).order(:name)

        render json: {
                 ai_secrets:
                   ActiveModel::ArraySerializer.new(
                     secrets,
                     each_serializer: AiSecretSerializer,
                     root: false,
                   ).as_json,
               }
      end

      def show
        secret = AiSecret.includes(:llm_models, :embedding_definitions).find(params[:id])
        render json: AiSecretSerializer.new(secret, scope: { unmask: true })
      end

      def new
      end

      def edit
      end

      def create
        secret = AiSecret.new(ai_secret_params)
        secret.created_by_id = current_user.id

        if secret.save
          render json: AiSecretSerializer.new(secret), status: :created
        else
          render_json_error secret
        end
      end

      def update
        secret = AiSecret.find(params[:id])

        attrs = ai_secret_params
        attrs.delete(:secret) if attrs[:secret] == "********"

        if secret.update(attrs)
          render json: AiSecretSerializer.new(secret)
        else
          render_json_error secret
        end
      end

      def destroy
        secret = AiSecret.find(params[:id])

        if secret.in_use?
          return(
            render_json_error(I18n.t("discourse_ai.secrets.delete_failed_in_use"), status: 409)
          )
        end

        secret.destroy!
        head :no_content
      end

      private

      def ai_secret_params
        params.require(:ai_secret).permit(:name, :secret)
      end
    end
  end
end
