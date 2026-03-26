# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiMcpServersController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      before_action :find_ai_mcp_server, only: %i[edit update destroy oauth_start oauth_disconnect]
      skip_before_action :check_xhr, :preload_json, only: %i[oauth_start oauth_callback]

      def index
        render json: {
                 ai_mcp_servers:
                   ActiveModel::ArraySerializer.new(
                     AiMcpServer.order(:name),
                     each_serializer: AiMcpServerSerializer,
                     root: false,
                   ).as_json,
                 meta: {
                   ai_secrets:
                     ActiveModel::ArraySerializer.new(
                       AiSecret.order(:name),
                       each_serializer: AiSecretSerializer,
                       root: false,
                     ).as_json,
                 },
               }
      end

      def new
      end

      def edit
        render json: AiMcpServerSerializer.new(@ai_mcp_server)
      end

      def create
        ai_mcp_server = AiMcpServer.new(ai_mcp_server_params)
        ai_mcp_server.created_by_id = current_user.id

        if ai_mcp_server.save
          log_ai_mcp_server_creation(ai_mcp_server)
          render json: AiMcpServerSerializer.new(ai_mcp_server), status: :created
        else
          render_json_error ai_mcp_server
        end
      end

      def update
        initial_attributes = @ai_mcp_server.attributes.dup
        update_params = ai_mcp_server_params

        if @ai_mcp_server.oauth? && update_params[:oauth_client_registration] != "manual" &&
             @ai_mcp_server.oauth_client_registration != "manual"
          update_params = update_params.except(:oauth_client_id, :oauth_client_secret_ai_secret_id)
        end

        if @ai_mcp_server.update(update_params)
          log_ai_mcp_server_update(@ai_mcp_server, initial_attributes)
          render json: AiMcpServerSerializer.new(@ai_mcp_server)
        else
          render_json_error @ai_mcp_server
        end
      end

      def destroy
        details = {
          mcp_server_id: @ai_mcp_server.id,
          name: @ai_mcp_server.name,
          subject: @ai_mcp_server.name,
        }

        @ai_mcp_server.destroy!
        log_ai_mcp_server_deletion(details)
        head :no_content
      end

      def oauth_start
        if @ai_mcp_server.new_record? || !@ai_mcp_server.oauth?
          return render_json_error(I18n.t("discourse_ai.mcp_servers.errors.oauth_not_configured"))
        end

        redirect_to(
          DiscourseAi::Mcp::OAuthFlow.start!(server: @ai_mcp_server, user: current_user),
          allow_other_host: true,
        )
      rescue StandardError => e
        @ai_mcp_server.mark_oauth_error!(e.message)
        redirect_to @ai_mcp_server.admin_edit_url
      end

      def oauth_callback
        ai_mcp_server =
          DiscourseAi::Mcp::OAuthFlow.complete!(params: params, current_user: current_user)
        redirect_to ai_mcp_server.admin_edit_url
      rescue DiscourseAi::Mcp::OAuthFlow::OAuthError => e
        Rails.logger.warn(
          "Discourse AI MCP OAuth callback failed: #{e.message} (#{e.cause&.class}: #{e.cause&.message})",
        )
        if e.server.present?
          redirect_to e.server.admin_edit_url
        else
          flash[:error] = I18n.t(
            "discourse_ai.mcp_servers.errors.oauth_callback_failed",
            message: e.message,
          )
          redirect_to "/admin/plugins/discourse-ai/ai-tools"
        end
      end

      def oauth_disconnect
        DiscourseAi::Mcp::OAuthFlow.disconnect!(@ai_mcp_server)
        render json: AiMcpServerSerializer.new(@ai_mcp_server.reload)
      rescue StandardError => e
        render_json_error e.message, status: 400
      end

      def test
        persisted_server = params[:id].present? ? AiMcpServer.find(params[:id]) : nil
        ai_mcp_server = persisted_server || AiMcpServer.new
        ai_mcp_server.assign_attributes(ai_mcp_server_params)
        restore_dynamic_oauth_credentials!(ai_mcp_server, persisted_server)

        return render_json_error ai_mcp_server if !ai_mcp_server.valid?
        if oauth_reauthorization_required_for_test?(ai_mcp_server)
          ai_mcp_server = sanitized_oauth_test_server(ai_mcp_server)
        end

        if ai_mcp_server.oauth? && persisted_server.blank?
          return(
            render_json_error(
              I18n.t("discourse_ai.mcp_servers.errors.oauth_save_before_connect"),
              status: 400,
            )
          )
        end

        client = DiscourseAi::Mcp::Client.new(ai_mcp_server)
        initialized = client.initialize_session
        tools = client.list_tools(session_id: initialized[:session_id])

        render json: {
                 protocol_version: initialized[:result]["protocolVersion"],
                 server_capabilities: initialized[:result]["capabilities"] || {},
                 tool_count: tools.length,
                 tool_names: tools.map { |tool| tool["name"] },
               }
      rescue StandardError => e
        render_json_error e.message, status: 400
      end

      private

      def find_ai_mcp_server
        @ai_mcp_server = AiMcpServer.find(params[:id])
      end

      def ai_mcp_server_params
        params.require(:ai_mcp_server).permit(
          :name,
          :description,
          :url,
          :auth_type,
          :ai_secret_id,
          :auth_header,
          :auth_scheme,
          :oauth_client_registration,
          :oauth_client_id,
          :oauth_client_secret_ai_secret_id,
          :oauth_scopes,
          :enabled,
          :timeout_seconds,
        )
      end

      def ai_mcp_server_logger_fields
        {
          name: {
          },
          description: {
          },
          url: {
          },
          auth_type: {
          },
          ai_secret_id: {
            type: :sensitive,
            extract: false,
          },
          auth_header: {
          },
          auth_scheme: {
          },
          oauth_client_registration: {
          },
          oauth_client_id: {
          },
          oauth_client_secret_ai_secret_id: {
            type: :sensitive,
            extract: false,
          },
          oauth_scopes: {
          },
          oauth_token_type: {
          },
          oauth_access_token_expires_at: {
          },
          oauth_authorization_endpoint: {
          },
          oauth_token_endpoint: {
          },
          oauth_revocation_endpoint: {
          },
          oauth_issuer: {
          },
          oauth_resource_metadata_url: {
          },
          oauth_status: {
          },
          oauth_last_error: {
            type: :large_text,
          },
          oauth_last_authorized_at: {
          },
          oauth_last_refreshed_at: {
          },
          enabled: {
          },
          timeout_seconds: {
          },
          server_capabilities: {
            type: :large_text,
          },
          protocol_version: {
          },
          last_health_error: {
            type: :large_text,
          },
        }
      end

      def log_ai_mcp_server_creation(ai_mcp_server)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        entity_details = { mcp_server_id: ai_mcp_server.id, subject: ai_mcp_server.name }
        logger.log_creation(
          "mcp_server",
          ai_mcp_server,
          ai_mcp_server_logger_fields,
          entity_details,
        )
      end

      def log_ai_mcp_server_update(ai_mcp_server, initial_attributes)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        entity_details = { mcp_server_id: ai_mcp_server.id, subject: ai_mcp_server.name }
        logger.log_update(
          "mcp_server",
          ai_mcp_server,
          initial_attributes,
          ai_mcp_server_logger_fields,
          entity_details,
        )
      end

      def log_ai_mcp_server_deletion(details)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        logger.log_deletion("mcp_server", details)
      end

      def restore_dynamic_oauth_credentials!(ai_mcp_server, persisted_server)
        return if persisted_server.blank? || !ai_mcp_server.oauth?
        return if ai_mcp_server.oauth_client_registration == "manual"

        ai_mcp_server.oauth_client_id = persisted_server.oauth_client_id
        ai_mcp_server.oauth_client_secret_ai_secret_id =
          persisted_server.oauth_client_secret_ai_secret_id
      end

      def oauth_reauthorization_required_for_test?(ai_mcp_server)
        return false if !ai_mcp_server.oauth? || !ai_mcp_server.persisted?

        trigger_fields = AiMcpServer::OAUTH_REAUTH_TRIGGER_FIELDS
        if ai_mcp_server.oauth_client_registration != "manual"
          trigger_fields -= %w[oauth_client_id oauth_client_secret_ai_secret_id]
        end
        (ai_mcp_server.changes_to_save.keys & trigger_fields).present?
      end

      def sanitized_oauth_test_server(ai_mcp_server)
        ai_mcp_server.dup.tap do |server|
          server.oauth_status = "disconnected"
          server.oauth_access_token_expires_at = nil
          server.oauth_token_type = nil
          server.oauth_last_error = nil
          server.oauth_last_authorized_at = nil
          server.oauth_last_refreshed_at = nil
        end
      end
    end
  end
end
