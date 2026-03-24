# frozen_string_literal: true

module DiscourseWorkflows
  class Template::List
    include Service::Base

    model :templates, :load_templates, optional: true

    private

    def load_templates
      Dir
        .glob(File.join(DiscourseWorkflows::TEMPLATES_PATH, "*.json"))
        .sort
        .filter_map do |path|
          data = JSON.parse(File.read(path))
          id = File.basename(path, ".json")
          {
            id: id,
            name: data["name"],
            description: data["description"],
            node_types: data["nodes"].map { |n| n["type"] }.uniq,
          }
        rescue JSON::ParserError
          nil
        end
    end
  end
end
