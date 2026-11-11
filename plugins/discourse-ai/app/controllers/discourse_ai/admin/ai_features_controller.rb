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
          enabled_setting:
            serialize_enabled_setting(
              a_module.toggle_setting,
              setup_complete: a_module.setup_complete?,
            ),
          status: a_module.status,
          model_names: a_module.model_names,
          features:
            a_module.features.select(&:visible?).map { |feature| serialize_feature(feature) },
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
          enabled_setting: serialize_enabled_setting(feature.toggle_setting),
          needs_setup: feature.setup_note,
          agentless: (true if feature.agentless?),
          **serialize_agent_access(feature),
        }.compact.merge(feature.metadata)
      end

      def serialize_agent_access(feature)
        return {} if !feature.access_by_agent_groups?

        shared_with =
          feature
            .agent_ids
            .flat_map { |id| features_by_agent_id.fetch(id, []) }
            .uniq
            .reject do |other|
              other.module_name == feature.module_name && other.name == feature.name
            end
            .map { |other| { module_name: other.module_name, name: other.name } }

        { access_by_agent_groups: true, shared_with: }
      end

      def serialize_enabled_setting(name, setup_complete: true)
        return if name.blank? || !SiteSetting.respond_to?(name)

        value = SiteSetting.get(name)
        { name:, value:, can_enable: value || (setup_complete && can_enable_setting?(name)) }
      end

      def can_enable_setting?(name)
        SiteSetting.type_supervisor.to_db_value(name.to_sym, true)
        true
      rescue Discourse::InvalidParameters
        false
      end

      def serialize_agent(agent)
        return nil if agent.blank?

        serialize_data(agent, AiFeaturesAgentSerializer, root: false)
      end

      private

      def agent_id_obj_hash
        @agent_id_obj_hash ||= AiAgent.where(id: features_by_agent_id.keys).index_by(&:id)
      end

      def features_by_agent_id
        @features_by_agent_id ||=
          DiscourseAi::Configuration::Feature
            .all
            .each_with_object(Hash.new { |hash, id| hash[id] = [] }) do |feature, by_agent|
              feature.agent_ids.each { |id| by_agent[id] << feature }
            end
      end
    end
  end
end
