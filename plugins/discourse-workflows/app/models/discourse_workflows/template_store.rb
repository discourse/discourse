# frozen_string_literal: true

module DiscourseWorkflows
  class TemplateStore
    def self.summaries
      templates_by_id.map { |id, template| summary_for(id, template) }
    end

    def self.find(id)
      templates_by_id[id]&.deep_dup
    end

    def self.reset_cache!
      remove_instance_variable(:@templates_by_id) if defined?(@templates_by_id)
    end

    def self.templates_by_id
      @templates_by_id ||= load_templates
    end
    private_class_method :templates_by_id

    def self.load_templates
      Dir
        .glob(File.join(DiscourseWorkflows::TEMPLATES_PATH, "*.json"))
        .sort
        .each_with_object({}) do |path, templates|
          id = File.basename(path, ".json")
          templates[id] = JSON.parse(File.read(path))
        rescue JSON::ParserError
          next
        end
    end
    private_class_method :load_templates

    def self.summary_for(id, template)
      {
        id: id,
        name: template["name"],
        description: template["description"],
        node_types: template["nodes"].map { |node| node["type"] }.uniq,
      }.deep_dup
    end
    private_class_method :summary_for
  end
end
