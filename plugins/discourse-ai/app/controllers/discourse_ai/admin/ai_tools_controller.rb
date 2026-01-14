# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiToolsController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      before_action :find_ai_tool, only: %i[test edit update destroy export]

      def index
        ai_tools = AiTool.all
        render_serialized({ ai_tools: ai_tools }, AiCustomToolListSerializer, root: false)
      end

      def new
      end

      def edit
        render_serialized(@ai_tool, AiCustomToolSerializer)
      end

      def create
        ai_tool = AiTool.new(ai_tool_params)
        ai_tool.created_by_id = current_user.id

        if ai_tool.save
          RagDocumentFragment.link_target_and_uploads(ai_tool, attached_upload_ids)
          log_ai_tool_creation(ai_tool)
          render_serialized(ai_tool, AiCustomToolSerializer, status: :created)
        else
          render_json_error ai_tool
        end
      end

      def export
        response.headers[
          "Content-Disposition"
        ] = "attachment; filename=\"#{@ai_tool.tool_name}.json\""
        render_serialized(@ai_tool, AiCustomToolSerializer)
      end

      def import
        existing_tool = AiTool.find_by(tool_name: ai_tool_params[:tool_name])
        force_update = params[:force].present? && params[:force].to_s.downcase == "true"

        if existing_tool && !force_update
          return(
            render_json_error "Tool with tool_name '#{ai_tool_params[:tool_name]}' already exists. Use force=true to overwrite.",
                              status: :conflict
          )
        end

        if existing_tool && force_update
          initial_attributes = existing_tool.attributes.dup
          if existing_tool.update(ai_tool_params)
            log_ai_tool_update(existing_tool, initial_attributes)
            render_serialized(existing_tool, AiCustomToolSerializer)
          else
            render_json_error existing_tool
          end
        else
          ai_tool = AiTool.new(ai_tool_params)
          ai_tool.created_by_id = current_user.id

          if ai_tool.save
            log_ai_tool_creation(ai_tool)
            render_serialized(ai_tool, AiCustomToolSerializer, status: :created)
          else
            render_json_error ai_tool
          end
        end
      end

      def update
        initial_attributes = @ai_tool.attributes.dup

        if @ai_tool.update(ai_tool_params)
          RagDocumentFragment.update_target_uploads(@ai_tool, attached_upload_ids)
          log_ai_tool_update(@ai_tool, initial_attributes)
          render_serialized(@ai_tool, AiCustomToolSerializer)
        else
          render_json_error @ai_tool
        end
      end

      def destroy
        tool_logger_details = {
          tool_id: @ai_tool.id,
          name: @ai_tool.name,
          tool_name: @ai_tool.tool_name,
          subject: @ai_tool.name,
        }

        if @ai_tool.destroy
          log_ai_tool_deletion(tool_logger_details)
          head :no_content
        else
          render_json_error @ai_tool
        end
      end

      def test
        @ai_tool.assign_attributes(ai_tool_params) if params[:ai_tool]
        parameters = params[:parameters].to_unsafe_h

        # we need an llm so we have a tokenizer
        # but will do without if none is available
        llm = LlmModel.first&.to_llm
        runner = @ai_tool.runner(parameters, llm: llm, bot_user: current_user)
        result = runner.invoke

        if result.is_a?(Hash) && result[:error]
          render_json_error result[:error]
        else
          render json: { output: result }
        end
      rescue ActiveRecord::RecordNotFound => e
        render_json_error e.message, status: 400
      rescue => e
        render_json_error "Error executing the tool: #{e.message}", status: 400
      end

      private

      def attached_upload_ids
        params[:ai_tool][:rag_uploads].to_a.map { |h| h[:id] }
      end

      def find_ai_tool
        @ai_tool = AiTool.find(params[:id].to_i)
      end

      def ai_tool_params
        params
          .require(:ai_tool)
          .permit(
            :name,
            :tool_name,
            :description,
            :script,
            :summary,
            :rag_chunk_tokens,
            :rag_chunk_overlap_tokens,
            :rag_llm_model_id,
            rag_uploads: [:id],
            parameters: [:name, :type, :description, :required, enum: []],
          )
          .except(:rag_uploads)
      end

      def ai_tool_logger_fields
        {
          name: {
          },
          tool_name: {
          },
          description: {
          },
          summary: {
          },
          enabled: {
          },
          rag_chunk_tokens: {
          },
          rag_chunk_overlap_tokens: {
          },
          rag_llm_model_id: {
          },
          script: {
            type: :large_text,
          },
          parameters: {
            type: :large_text,
          },
        }
      end

      def log_ai_tool_creation(ai_tool)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)

        entity_details = { tool_id: ai_tool.id, subject: ai_tool.name }
        entity_details[:parameter_count] = ai_tool.parameters.size if ai_tool.parameters.present?

        logger.log_creation("tool", ai_tool, ai_tool_logger_fields, entity_details)
      end

      def log_ai_tool_update(ai_tool, initial_attributes)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        entity_details = { tool_id: ai_tool.id, subject: ai_tool.name }

        logger.log_update(
          "tool",
          ai_tool,
          initial_attributes,
          ai_tool_logger_fields,
          entity_details,
        )
      end

      def log_ai_tool_deletion(tool_details)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        logger.log_deletion("tool", tool_details)
      end
    end
  end
end
