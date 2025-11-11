# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiSpamController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      def show
        render json: AiSpamSerializer.new(spam_config, root: false)
      end

      def update
        initial_settings = AiModerationSetting.spam

        initial_data = {
          custom_instructions: initial_settings&.data&.dig("custom_instructions"),
          llm_model_id: initial_settings&.llm_model_id,
          ai_persona_id: initial_settings&.ai_persona_id,
        }

        initial_custom_instructions = initial_settings&.data&.dig("custom_instructions")
        initial_llm_model_id = initial_settings&.llm_model_id

        updated_params = {}
        if allowed_params.key?(:llm_model_id)
          llm_model_id = updated_params[:llm_model_id] = allowed_params[:llm_model_id]
        end

        if allowed_params.key?(:ai_persona_id)
          updated_params[:ai_persona_id] = allowed_params[:ai_persona_id]
          persona = AiPersona.find_by(id: allowed_params[:ai_persona_id])
          if persona.nil? ||
               persona.response_format.to_a.none? { |rf|
                 rf["key"] == "spam" && rf["type"] == "boolean"
               }
            return(
              render_json_error(
                I18n.t("discourse_ai.llm.configuration.invalid_persona_response_format"),
                status: 422,
              )
            )
          end
        end
        updated_params[:data] = {
          custom_instructions: allowed_params[:custom_instructions],
        } if allowed_params.key?(:custom_instructions)

        if updated_params.present?
          # not using upsert cause we will not get the correct validation errors
          if AiModerationSetting.spam
            AiModerationSetting.spam.update!(updated_params)
          else
            AiModerationSetting.create!(updated_params.merge(setting_type: :spam))
          end

          log_ai_spam_update(initial_data, allowed_params)
        end

        is_enabled = ActiveModel::Type::Boolean.new.cast(allowed_params[:is_enabled])

        if allowed_params.key?(:is_enabled)
          if is_enabled && !AiModerationSetting.spam&.llm_model_id
            return(
              render_json_error(
                I18n.t("discourse_ai.llm.configuration.must_select_model"),
                status: 422,
              )
            )
          end

          SiteSetting.set_and_log("ai_spam_detection_enabled", is_enabled, current_user)
        end

        render json: AiSpamSerializer.new(spam_config, root: false)
      end

      def test
        url = params[:post_url].to_s
        post = nil

        if url.match?(/^\d+$/)
          post_id = url.to_i
          post = Post.find_by(id: post_id)
        end

        route = UrlHelper.rails_route_from_url(url) if !post

        if route
          if route[:controller] == "topics"
            post_number = route[:post_number] || 1
            post = Post.with_deleted.find_by(post_number: post_number, topic_id: route[:topic_id])
          end
        end

        raise Discourse::NotFound if !post

        result =
          DiscourseAi::AiModeration::SpamScanner.test_post(
            post,
            custom_instructions: params[:custom_instructions],
            llm_id: params[:llm_id],
          )

        render json: result
      end

      def fix_errors
        case params[:error]
        when "spam_scanner_not_admin"
          begin
            DiscourseAi::AiModeration::SpamScanner.fix_spam_scanner_not_admin
            render json: success_json
          rescue ActiveRecord::RecordInvalid
            render_json_error(
              I18n.t("discourse_ai.spam_detection.bot_user_update_failed"),
              status: :unprocessable_entity,
            )
          rescue StandardError
            render_json_error(
              I18n.t("discourse_ai.spam_detection.unexpected"),
              status: :internal_server_error,
            )
          end
        else
          render_json_error(
            I18n.t("discourse_ai.spam_detection.invalid_error_type"),
            status: :bad_request,
          )
        end
      end

      private

      def log_ai_spam_update(initial_data, params)
        changes_to_log = {}

        initial_llm_model_id = initial_data[:llm_model_id]
        if params.key?(:llm_model_id) && initial_llm_model_id.to_s != params[:llm_model_id].to_s
          old_model_name =
            LlmModel.find_by(id: initial_llm_model_id)&.display_name || initial_llm_model_id
          new_model_name =
            LlmModel.find_by(id: params[:llm_model_id])&.display_name || params[:llm_model_id]

          changes_to_log[:llm_model_id] = "#{old_model_name} → #{new_model_name}"
        end

        initial_custom_instructions = initial_data[:custom_instructions]
        if params.key?(:custom_instructions) &&
             initial_custom_instructions != params[:custom_instructions]
          changes_to_log[:custom_instructions] = params[:custom_instructions]
        end

        initial_ai_persona_id = initial_data[:ai_persona_id]
        if params.key?(:ai_persona_id) && initial_ai_persona_id.to_s != params[:ai_persona_id].to_s
          old_persona_name =
            AiPersona.find_by(id: initial_ai_persona_id)&.name || initial_ai_persona_id
          new_persona_name =
            AiPersona.find_by(id: params[:ai_persona_id])&.name || params[:ai_persona_id]

          changes_to_log[:ai_persona_id] = "#{old_persona_name} → #{new_persona_name}"
        end

        if changes_to_log.present?
          changes_to_log[:subject] = I18n.t("discourse_ai.spam_detection.logging_subject")
          logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
          logger.log_custom("update_ai_spam_settings", changes_to_log)
        end
      end

      def allowed_params
        params.permit(:is_enabled, :llm_model_id, :custom_instructions, :ai_persona_id)
      end

      def spam_config
        spam_config = {
          enabled: SiteSetting.ai_spam_detection_enabled,
          settings: AiModerationSetting.spam,
        }

        spam_config[:stats] = DiscourseAi::AiModeration::SpamReport.generate(min_date: 1.week.ago)

        if spam_config[:stats].scanned_count > 0
          spam_config[
            :flagging_username
          ] = DiscourseAi::AiModeration::SpamScanner.flagging_user&.username
        end
        spam_config
      end
    end
  end
end
