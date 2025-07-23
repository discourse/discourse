# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiLlmsController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      def index
        llms = LlmModel.all.includes(:llm_quotas).order(:display_name)

        render json: {
                 ai_llms:
                   ActiveModel::ArraySerializer.new(
                     llms,
                     each_serializer: LlmModelSerializer,
                     root: false,
                     scope: {
                       llm_usage: DiscourseAi::Configuration::LlmEnumerator.global_usage,
                     },
                   ).as_json,
                 meta: {
                   provider_params: LlmModel.provider_params,
                   presets: DiscourseAi::Completions::Llm.presets,
                   providers: DiscourseAi::Completions::Llm.provider_names,
                   tokenizers:
                     DiscourseAi::Completions::Llm.tokenizer_names.map { |tn|
                       { id: tn, name: tn.split("::").last }
                     },
                 },
               }
      end

      def new
      end

      def edit
        llm_model = LlmModel.find(params[:id])
        render json: LlmModelSerializer.new(llm_model)
      end

      def create
        llm_model = LlmModel.new(ai_llm_params)

        # we could do nested attributes but the mechanics are not ideal leading
        # to lots of complex debugging, this is simpler
        quota_params.each { |quota| llm_model.llm_quotas.build(quota) } if quota_params

        if llm_model.save
          llm_model.toggle_companion_user
          log_llm_model_creation(llm_model)
          render json: LlmModelSerializer.new(llm_model), status: :created
        else
          render_json_error llm_model
        end
      end

      def update
        llm_model = LlmModel.find(params[:id])

        # Capture initial state for logging
        initial_attributes = llm_model.attributes.dup
        initial_quotas = llm_model.llm_quotas.map(&:attributes)

        if params[:ai_llm].key?(:llm_quotas)
          if quota_params
            existing_quota_group_ids = llm_model.llm_quotas.pluck(:group_id)
            new_quota_group_ids = quota_params.map { |q| q[:group_id] }

            llm_model
              .llm_quotas
              .where(group_id: existing_quota_group_ids - new_quota_group_ids)
              .destroy_all

            quota_params.each do |quota_param|
              quota = llm_model.llm_quotas.find_or_initialize_by(group_id: quota_param[:group_id])
              quota.update!(quota_param)
            end
          else
            llm_model.llm_quotas.destroy_all
          end
        end

        if llm_model.seeded?
          return render_json_error(I18n.t("discourse_ai.llm.cannot_edit_builtin"), status: 403)
        end

        if llm_model.update(ai_llm_params(updating: llm_model))
          llm_model.toggle_companion_user
          log_llm_model_update(llm_model, initial_attributes, initial_quotas)
          render json: LlmModelSerializer.new(llm_model)
        else
          render_json_error llm_model
        end
      end

      def destroy
        llm_model = LlmModel.find(params[:id])

        if llm_model.seeded?
          return render_json_error(I18n.t("discourse_ai.llm.cannot_delete_builtin"), status: 403)
        end

        in_use_by = DiscourseAi::Configuration::LlmValidator.new.modules_using(llm_model)

        if !in_use_by.empty?
          return(
            render_json_error(
              I18n.t(
                "discourse_ai.llm.delete_failed",
                settings: in_use_by.join(", "),
                count: in_use_by.length,
              ),
              status: 409,
            )
          )
        end

        # Capture model details for logging before destruction
        model_details = {
          model_id: llm_model.id,
          display_name: llm_model.display_name,
          name: llm_model.name,
          provider: llm_model.provider,
        }

        # Clean up companion users
        llm_model.enabled_chat_bot = false
        llm_model.toggle_companion_user

        if llm_model.destroy
          log_llm_model_deletion(model_details)
          head :no_content
        else
          render_json_error llm_model
        end
      end

      def test
        RateLimiter.new(current_user, "llm_test_#{current_user.id}", 3, 1.minute).performed!

        llm_model = LlmModel.new(ai_llm_params)

        DiscourseAi::Configuration::LlmValidator.new.run_test(llm_model)

        render json: { success: true }
      rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed => e
        render json: { success: false, error: e.message }
      end

      private

      def quota_params
        if params[:ai_llm][:llm_quotas].present?
          params[:ai_llm][:llm_quotas].map do |quota|
            mapped = {}
            mapped[:group_id] = quota[:group_id].to_i
            mapped[:max_tokens] = quota[:max_tokens].to_i if quota[:max_tokens].present?
            mapped[:max_usages] = quota[:max_usages].to_i if quota[:max_usages].present?
            mapped[:duration_seconds] = quota[:duration_seconds].to_i
            mapped
          end
        end
      end

      def ai_llm_params(updating: nil)
        return {} if params[:ai_llm].blank?

        permitted =
          params.require(:ai_llm).permit(
            :display_name,
            :name,
            :provider,
            :tokenizer,
            :max_prompt_tokens,
            :max_output_tokens,
            :api_key,
            :enabled_chat_bot,
            :vision_enabled,
            :input_cost,
            :cached_input_cost,
            :output_cost,
          )

        provider = updating ? updating.provider : permitted[:provider]
        permit_url = provider != LlmModel::BEDROCK_PROVIDER_NAME

        new_url = params.dig(:ai_llm, :url)
        permitted[:url] = new_url if permit_url && new_url

        extra_field_names = LlmModel.provider_params.dig(provider&.to_sym)
        if extra_field_names.present?
          received_prov_params =
            params.dig(:ai_llm, :provider_params)&.slice(*extra_field_names.keys)

          if received_prov_params.present?
            received_prov_params.each do |pname, value|
              if extra_field_names[pname.to_sym] == :checkbox
                received_prov_params[pname] = ActiveModel::Type::Boolean.new.cast(value)
              end
            end

            permitted[:provider_params] = received_prov_params.permit!
          end
        end

        permitted
      end

      def ai_llm_logger_fields
        {
          display_name: {
          },
          name: {
          },
          provider: {
          },
          tokenizer: {
          },
          url: {
          },
          max_prompt_tokens: {
          },
          max_output_tokens: {
          },
          enabled_chat_bot: {
          },
          vision_enabled: {
          },
          api_key: {
            type: :sensitive,
          },
          input_cost: {
          },
          output_cost: {
          },
          # JSON fields should be tracked as simple changes
          json_fields: [:provider_params],
        }
      end

      def log_llm_model_creation(llm_model)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        entity_details = { model_id: llm_model.id, subject: llm_model.display_name }

        # Add quota information as a special case
        if llm_model.llm_quotas.any?
          entity_details[:quotas] = llm_model
            .llm_quotas
            .map do |quota|
              "Group #{quota.group_id}: #{quota.max_tokens} tokens, #{quota.max_usages} usages, #{quota.duration_seconds}s"
            end
            .join("; ")
        end

        logger.log_creation("llm_model", llm_model, ai_llm_logger_fields, entity_details)
      end

      def log_llm_model_update(llm_model, initial_attributes, initial_quotas)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        entity_details = { model_id: llm_model.id, subject: llm_model.display_name }

        # Track quota changes separately as they're a special case
        current_quotas = llm_model.llm_quotas.reload.map(&:attributes)
        if initial_quotas != current_quotas
          initial_quota_summary =
            initial_quotas
              .map { |q| "Group #{q["group_id"]}: #{q["max_tokens"]} tokens" }
              .join("; ")
          current_quota_summary =
            current_quotas
              .map { |q| "Group #{q["group_id"]}: #{q["max_tokens"]} tokens" }
              .join("; ")
          entity_details[:quotas_changed] = true
          entity_details[:quotas] = "#{initial_quota_summary} → #{current_quota_summary}"
        end

        logger.log_update(
          "llm_model",
          llm_model,
          initial_attributes,
          ai_llm_logger_fields,
          entity_details,
        )
      end

      def log_llm_model_deletion(model_details)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        model_details[:subject] = model_details[:display_name]
        logger.log_deletion("llm_model", model_details)
      end
    end
  end
end
