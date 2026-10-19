# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiDecisionModelsController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      # The red square meets minimum image-size requirements; tiny placeholders may be rejected.
      TEST_IMAGE =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAARgAAAEYCAMAAACwUBm+AAAAA1BMVEX/AAAZ4gk3AAAAYklEQVR42u3BAQEAAACCIP+vbkhAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHwaM2cAAalku0EAAAAASUVORK5CYII="

      def index
        decision_models =
          DecisionModel.includes(:decision_model_credit_allocation).order(:display_name)

        render json: {
                 ai_decision_models:
                   ActiveModel::ArraySerializer.new(
                     decision_models,
                     each_serializer: AiDecisionModelSerializer,
                     scope: guardian,
                     root: false,
                   ).as_json,
                 meta: {
                   providers: DecisionModel::PROVIDERS,
                   presets: DecisionModel.presets,
                   custom_header_limits: DecisionModel::CUSTOM_HEADER_LIMITS,
                   ai_secrets: AiSecret.order(:name).select(:id, :name).as_json(only: %i[id name]),
                 },
               }
      end

      def new
      end

      def edit
        decision_model = DecisionModel.find(params[:id])
        render json: AiDecisionModelSerializer.new(decision_model, scope: guardian)
      end

      def create
        decision_model = DecisionModel.new(decision_model_params)

        if decision_model.save
          DiscourseAi::Utils::AiStaffActionLogger.new(current_user).log_creation(
            "decision_model",
            decision_model,
            logger_fields,
            { decision_model_id: decision_model.id, subject: decision_model.display_name },
          )
          render json: AiDecisionModelSerializer.new(decision_model, scope: guardian),
                 status: :created
        else
          render_json_error decision_model
        end
      end

      def update
        decision_model = DecisionModel.find(params[:id])
        return render_seeded_error if decision_model.seeded?
        initial_attributes = decision_model.attributes.dup

        if decision_model.update(decision_model_params)
          DiscourseAi::Utils::AiStaffActionLogger.new(current_user).log_update(
            "decision_model",
            decision_model,
            initial_attributes,
            logger_fields,
            { decision_model_id: decision_model.id, subject: decision_model.display_name },
          )
          render json: AiDecisionModelSerializer.new(decision_model, scope: guardian)
        else
          render_json_error decision_model
        end
      end

      def destroy
        decision_model = DecisionModel.find(params[:id])
        return render_seeded_error if decision_model.seeded?

        details =
          decision_model
            .attributes
            .symbolize_keys
            .slice(*logger_fields.keys)
            .merge(decision_model_id: decision_model.id, subject: decision_model.display_name)

        details[:custom_headers] = "[FILTERED]" if decision_model.custom_headers.present?

        if decision_model.destroy
          DiscourseAi::Utils::AiStaffActionLogger.new(current_user).log_deletion(
            "decision_model",
            details,
          )
          head :no_content
        else
          render_json_error decision_model
        end
      end

      def test
        RateLimiter.new(
          current_user,
          "ai_decision_models_test_#{current_user.id}",
          6,
          1.minute,
          apply_limit_to_staff: true,
        ).performed!

        decision_model = DecisionModel.new(decision_model_params)
        decision_model.display_name = "Test" if decision_model.display_name.blank?
        if !decision_model.valid?
          return(
            render json: { success: false, error: decision_model.errors.full_messages.join(", ") }
          )
        end

        questions = [
          { type: "yes_no", name: "greeting", instructions: "Is this message a greeting?" },
        ]
        images = []
        if decision_model.vision_enabled
          questions << {
            type: "yes_no",
            name: "red_image",
            instructions: "Is the attached image a solid red square?",
          }
          images << TEST_IMAGE
        end

        result =
          DiscourseAi::Decisions::Client.new(decision_model, timeout: 10, max_attempts: 1).decide(
            "Hello! How are you doing today?",
            questions:,
            images:,
            user: current_user,
            feature_name: "decision_model_test",
          )

        if result.refusals.present?
          render json: {
                   success: false,
                   error: I18n.t("discourse_ai.decision_models.test_refused"),
                 }
        elsif decision_model.vision_enabled && result["red_image"].probability < 0.5
          render json: {
                   success: false,
                   error: I18n.t("discourse_ai.decision_models.test_image_not_read"),
                 }
        else
          render json: { success: true, probability: result["greeting"].probability }
        end
      rescue DiscourseAi::Decisions::Error => e
        render json: { success: false, error: e.message }
      end

      private

      def render_seeded_error
        render_json_error(I18n.t("discourse_ai.decision_models.cannot_modify_seeded"), status: 403)
      end

      def decision_model_params
        input = params.require(:ai_decision_model)
        permitted =
          input.permit(:display_name, :name, :provider, :url, :ai_secret_id, :vision_enabled)
        # Preserve malformed JSON shapes so validation rejects them rather than silently dropping them.
        permitted[:custom_headers] = input.to_unsafe_h[:custom_headers] if input.key?(
          :custom_headers,
        )
        permitted
      end

      def logger_fields
        %i[display_name name provider url ai_secret_id vision_enabled]
          .index_with { {} }
          .merge(custom_headers: { type: :sensitive })
      end
    end
  end
end
