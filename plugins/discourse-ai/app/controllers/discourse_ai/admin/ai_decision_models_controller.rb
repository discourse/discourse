# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiDecisionModelsController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      def index
        decision_models = DecisionModel.includes(:ai_secret).order(:display_name)

        render json: {
                 ai_decision_models:
                   ActiveModel::ArraySerializer.new(
                     decision_models,
                     each_serializer: AiDecisionModelSerializer,
                     root: false,
                   ).as_json,
                 meta: {
                   providers: DecisionModel.provider_names,
                   presets: DecisionModel.presets,
                   ai_secrets:
                     ActiveModel::ArraySerializer.new(
                       AiSecret.all.order(:name),
                       each_serializer: AiSecretSerializer,
                       root: false,
                     ).as_json,
                 },
               }
      end

      def new
      end

      def edit
        decision_model = DecisionModel.find(params[:id])
        render json: AiDecisionModelSerializer.new(decision_model)
      end

      def create
        decision_model = DecisionModel.new(decision_model_params)

        if decision_model.save
          log_decision_model_creation(decision_model)
          render json: AiDecisionModelSerializer.new(decision_model), status: :created
        else
          render_json_error decision_model
        end
      end

      def update
        decision_model = DecisionModel.find(params[:id])
        initial_attributes = decision_model.attributes.dup

        if decision_model.update(decision_model_params)
          log_decision_model_update(decision_model, initial_attributes)
          render json: AiDecisionModelSerializer.new(decision_model)
        else
          render_json_error decision_model
        end
      end

      def destroy
        decision_model = DecisionModel.find(params[:id])

        details = {
          decision_model_id: decision_model.id,
          display_name: decision_model.display_name,
          name: decision_model.name,
          provider: decision_model.provider,
          subject: decision_model.display_name,
        }

        if decision_model.destroy
          log_decision_model_deletion(details)
          head :no_content
        else
          render_json_error decision_model
        end
      end

      def test
        RateLimiter.new(
          current_user,
          "ai_decision_models_test_#{current_user.id}",
          3,
          1.minute,
        ).performed!

        decision_model = DecisionModel.new(decision_model_params)
        if !decision_model.valid?
          return(
            render json: { success: false, error: decision_model.errors.full_messages.join(", ") }
          )
        end

        # A single short attempt, since this runs inside a web request.
        result =
          DiscourseAi::Decisions::Client.new(decision_model, timeout: 10, max_attempts: 1).decide(
            "Hello! How are you doing today?",
            questions: [
              { type: "yes_no", name: "greeting", instructions: "Is this message a greeting?" },
            ],
            user: current_user,
            feature_name: "decision_model_test",
          )

        answer = result["greeting"]
        if answer.refusal?
          render json: {
                   success: false,
                   error: I18n.t("discourse_ai.decision_models.test_refused"),
                 }
        else
          render json: { success: true, probability: answer.probability }
        end
      rescue DiscourseAi::Decisions::Error => e
        render json: { success: false, error: e.message }
      end

      private

      def decision_model_params
        params.require(:ai_decision_model).permit(
          :display_name,
          :name,
          :provider,
          :url,
          :ai_secret_id,
          :vision_enabled,
        )
      end

      def logger_fields
        { display_name: {}, name: {}, provider: {}, url: {}, ai_secret_id: {}, vision_enabled: {} }
      end

      def log_decision_model_creation(decision_model)
        DiscourseAi::Utils::AiStaffActionLogger.new(current_user).log_creation(
          "decision_model",
          decision_model,
          logger_fields,
          { decision_model_id: decision_model.id, subject: decision_model.display_name },
        )
      end

      def log_decision_model_update(decision_model, initial_attributes)
        DiscourseAi::Utils::AiStaffActionLogger.new(current_user).log_update(
          "decision_model",
          decision_model,
          initial_attributes,
          logger_fields,
          { decision_model_id: decision_model.id, subject: decision_model.display_name },
        )
      end

      def log_decision_model_deletion(details)
        DiscourseAi::Utils::AiStaffActionLogger.new(current_user).log_deletion(
          "decision_model",
          details,
        )
      end
    end
  end
end
