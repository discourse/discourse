# frozen_string_literal: true

module DiscourseWorkflows
  class TemplatesController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    TEMPLATES_PATH = File.join(File.dirname(__FILE__), "../../..", "config/templates")

    def index
      templates = []

      Dir
        .glob(File.join(TEMPLATES_PATH, "*.json"))
        .sort
        .each do |path|
          data = JSON.parse(File.read(path))
          id = File.basename(path, ".json")
          templates << {
            id: id,
            name: data["name"],
            description: data["description"],
            node_types: data["nodes"].map { |n| n["type"] }.uniq,
          }
        rescue JSON::ParserError
          next
        end

      render json: { templates: templates }
    end

    def show
      path = File.join(TEMPLATES_PATH, "#{params[:id]}.json")
      raise Discourse::NotFound unless File.exist?(path)

      data = JSON.parse(File.read(path))
      render json: { template: data }
    rescue JSON::ParserError
      raise Discourse::NotFound
    end
  end
end
