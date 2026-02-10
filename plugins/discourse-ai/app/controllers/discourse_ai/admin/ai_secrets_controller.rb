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
          log_ai_secret_creation(secret)
          render json: AiSecretSerializer.new(secret), status: :created
        else
          render_json_error secret
        end
      end

      def update
        secret = AiSecret.find(params[:id])
        initial_attributes = secret.attributes.dup

        attrs = ai_secret_params

        if secret.update(attrs)
          log_ai_secret_update(secret, initial_attributes)
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

        secret_details = { secret_id: secret.id, display_name: secret.name, name: secret.name }

        secret.destroy!
        log_ai_secret_deletion(secret_details)
        head :no_content
      end

      private

      def ai_secret_params
        params.require(:ai_secret).permit(:name, :secret)
      end

      def ai_secret_logger_fields
        { name: {}, secret: { type: :sensitive } }
      end

      def log_ai_secret_creation(secret)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        entity_details = { secret_id: secret.id, subject: secret.name }
        logger.log_creation("secret", secret, ai_secret_logger_fields, entity_details)
      end

      def log_ai_secret_update(secret, initial_attributes)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        entity_details = { secret_id: secret.id, subject: secret.name }
        logger.log_update(
          "secret",
          secret,
          initial_attributes,
          ai_secret_logger_fields,
          entity_details,
        )
      end

      def log_ai_secret_deletion(secret_details)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        secret_details[:subject] = secret_details[:display_name]
        logger.log_deletion("secret", secret_details)
      end
    end
  end
end
