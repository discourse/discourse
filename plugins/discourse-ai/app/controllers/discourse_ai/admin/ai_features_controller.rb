# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiFeaturesController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      def index
        modules = DiscourseAi::Configuration::Module.all.select(&:visible?)
        render json: serialize_modules(modules)
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
          agents: feature.agent_ids.map { |id| serialize_agent(agent_id_obj_hash[id]) }.compact,
          llm_models:
            feature.llm_models.map do |llm_model|
              { id: llm_model.id, name: llm_model.display_name }
            end,
          enabled: feature.enabled?,
        }
      end

      def serialize_agent(agent)
        return nil if agent.blank?

        serialize_data(agent, AiFeaturesAgentSerializer, root: false)
      end

      private

      def agent_id_obj_hash
        @agent_id_obj_hash ||=
          begin
            ids = DiscourseAi::Configuration::Feature.all.map(&:agent_ids).flatten.uniq
            AiAgent.where(id: ids).index_by(&:id)
          end
      end
    end
  end
end
