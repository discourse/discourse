# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiEmbeddingsController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      def index
        embedding_defs = EmbeddingDefinition.all.order(:display_name)

        render json: {
                 ai_embeddings:
                   ActiveModel::ArraySerializer.new(
                     embedding_defs,
                     each_serializer: AiEmbeddingDefinitionSerializer,
                     root: false,
                   ).as_json,
                 meta: {
                   provider_params: EmbeddingDefinition.provider_params,
                   providers: EmbeddingDefinition.provider_names,
                   distance_functions: EmbeddingDefinition.distance_functions,
                   tokenizers:
                     EmbeddingDefinition.tokenizer_names.map { |tn|
                       { id: tn, name: tn.split("::").last }
                     },
                   presets: EmbeddingDefinition.presets,
                 },
               }
      end

      def new
      end

      def edit
        embedding_def = EmbeddingDefinition.find(params[:id])
        render json: AiEmbeddingDefinitionSerializer.new(embedding_def)
      end

      def create
        embedding_def = EmbeddingDefinition.new(ai_embeddings_params)

        if embedding_def.save
          log_ai_embedding_creation(embedding_def)
          render json: AiEmbeddingDefinitionSerializer.new(embedding_def), status: :created
        else
          render_json_error embedding_def
        end
      end

      def update
        embedding_def = EmbeddingDefinition.find(params[:id])

        if embedding_def.seeded?
          return(
            render_json_error(I18n.t("discourse_ai.embeddings.cannot_edit_builtin"), status: 403)
          )
        end

        initial_attributes = embedding_def.attributes.dup

        if embedding_def.update(ai_embeddings_params.except(:dimensions))
          log_ai_embedding_update(embedding_def, initial_attributes)
          render json: AiEmbeddingDefinitionSerializer.new(embedding_def)
        else
          render_json_error embedding_def
        end
      end

      def destroy
        embedding_def = EmbeddingDefinition.find(params[:id])

        if embedding_def.seeded?
          return(
            render_json_error(I18n.t("discourse_ai.embeddings.cannot_edit_builtin"), status: 403)
          )
        end

        if embedding_def.id == SiteSetting.ai_embeddings_selected_model.to_i
          return render_json_error(I18n.t("discourse_ai.embeddings.delete_failed"), status: 409)
        end

        embedding_details = {
          embedding_id: embedding_def.id,
          display_name: embedding_def.display_name,
          provider: embedding_def.provider,
          dimensions: embedding_def.dimensions,
          subject: embedding_def.display_name,
        }

        if embedding_def.destroy
          log_ai_embedding_deletion(embedding_details)
          head :no_content
        else
          render_json_error embedding_def
        end
      end

      def test
        RateLimiter.new(
          current_user,
          "ai_embeddings_test_#{current_user.id}",
          3,
          1.minute,
        ).performed!

        embedding_def = EmbeddingDefinition.new(ai_embeddings_params)
        DiscourseAi::Embeddings::Vector.new(embedding_def).vector_from("this is a test")

        render json: { success: true }
      rescue Net::HTTPBadResponse => e
        render json: { success: false, error: e.message }
      end

      private

      def ai_embeddings_params
        permitted =
          params.require(:ai_embedding).permit(
            :display_name,
            :dimensions,
            :max_sequence_length,
            :pg_function,
            :provider,
            :url,
            :api_key,
            :tokenizer_class,
            :embed_prompt,
            :search_prompt,
            :matryoshka_dimensions,
          )

        extra_field_names = EmbeddingDefinition.provider_params.dig(permitted[:provider]&.to_sym)
        if extra_field_names.present?
          received_prov_params =
            params.dig(:ai_embedding, :provider_params)&.slice(*extra_field_names.keys)

          if received_prov_params.present?
            permitted[:provider_params] = received_prov_params.permit!
          end
        end

        permitted
      end

      def ai_embeddings_logger_fields
        {
          display_name: {
          },
          provider: {
          },
          dimensions: {
          },
          url: {
          },
          tokenizer_class: {
          },
          max_sequence_length: {
          },
          embed_prompt: {
            type: :large_text,
          },
          search_prompt: {
            type: :large_text,
          },
          matryoshka_dimensions: {
          },
          api_key: {
            type: :sensitive,
          },
          # JSON fields should be tracked as simple changes
          json_fields: [:provider_params],
        }
      end

      def log_ai_embedding_creation(embedding_def)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        entity_details = { embedding_id: embedding_def.id, subject: embedding_def.display_name }
        logger.log_creation("embedding", embedding_def, ai_embeddings_logger_fields, entity_details)
      end

      def log_ai_embedding_update(embedding_def, initial_attributes)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        entity_details = { embedding_id: embedding_def.id, subject: embedding_def.display_name }

        logger.log_update(
          "embedding",
          embedding_def,
          initial_attributes,
          ai_embeddings_logger_fields,
          entity_details,
        )
      end

      def log_ai_embedding_deletion(embedding_details)
        logger = DiscourseAi::Utils::AiStaffActionLogger.new(current_user)
        logger.log_deletion("embedding", embedding_details)
      end
    end
  end
end
