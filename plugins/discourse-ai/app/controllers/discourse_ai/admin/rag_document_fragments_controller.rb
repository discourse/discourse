# frozen_string_literal: true

module DiscourseAi
  module Admin
    class RagDocumentFragmentsController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      def indexing_status_check
        if params[:target_type] == "AiPersona"
          @target = AiPersona.find(params[:target_id])
        elsif params[:target_type] == "AiTool"
          @target = AiTool.find(params[:target_id])
        else
          raise Discourse::InvalidParameters.new("Invalid target type")
        end

        render json: RagDocumentFragment.indexing_status(@target, @target.uploads)
      end

      def upload_file
        file = params[:file] || params[:files].first

        if !DiscourseAi::Embeddings.enabled?
          raise Discourse::InvalidAccess.new("Embeddings not enabled")
        end

        validate_extension!(file.original_filename)
        validate_file_size!(file.tempfile.size)

        hijack do
          upload =
            UploadCreator.new(
              file.tempfile,
              file.original_filename,
              type: "discourse_ai_rag_upload",
              skip_validations: true,
            ).create_for(current_user.id)

          if upload.persisted?
            render json: UploadSerializer.new(upload)
          else
            render json: failed_json.merge(errors: upload.errors.full_messages), status: 422
          end
        end
      end

      private

      def validate_extension!(filename)
        extension = File.extname(filename)[1..-1] || ""
        authorized_extensions = %w[txt md pdf]
        authorized_extensions.concat(%w[png jpg jpeg]) if SiteSetting.ai_rag_images_enabled
        if !authorized_extensions.include?(extension)
          raise Discourse::InvalidParameters.new(
                  I18n.t(
                    "upload.unauthorized",
                    authorized_extensions: authorized_extensions.join(" "),
                  ),
                )
        end
      end

      def validate_file_size!(filesize)
        max_size_bytes = 20.megabytes
        if filesize > max_size_bytes
          raise Discourse::InvalidParameters.new(
                  I18n.t(
                    "upload.attachments.too_large_humanized",
                    max_size: ActiveSupport::NumberHelper.number_to_human_size(max_size_bytes),
                  ),
                )
        end
      end
    end
  end
end
