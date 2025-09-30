# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiFeaturesController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      def index
        render json: serialize_modules(DiscourseAi::Configuration::Module.all)
      end

      def edit
        raise Discourse::InvalidParameters.new(:id) if params[:id].blank?

        a_module = DiscourseAi::Configuration::Module.find_by(id: params[:id].to_i)

        render json: serialize_module(a_module)
      end

      private

      def serialize_modules(modules)
        modules.map { |a_module| serialize_module(a_module) }
      end

      def serialize_module(a_module)
        return nil if a_module.blank?

        {
          id: a_module.id,
          module_name: a_module.name,
          module_enabled: a_module.enabled?,
          features: a_module.features.map { |f| serialize_feature(f) },
        }
      end

      def serialize_feature(feature)
        {
          name: feature.name,
          personas: feature.persona_ids.map { |id| serialize_persona(persona_id_obj_hash[id]) },
          llm_models:
            feature.llm_models.map do |llm_model|
              { id: llm_model.id, name: llm_model.display_name }
            end,
          enabled: feature.enabled?,
        }
      end

      def serialize_persona(persona)
        return nil if persona.blank?

        serialize_data(persona, AiFeaturesPersonaSerializer, root: false)
      end

      private

      def persona_id_obj_hash
        @persona_id_obj_hash ||=
          begin
            ids = DiscourseAi::Configuration::Feature.all.map(&:persona_ids).flatten.uniq
            AiPersona.where(id: ids).index_by(&:id)
          end
      end
    end
  end
end
