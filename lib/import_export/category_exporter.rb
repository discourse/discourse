require "import_export/base_exporter"
require "import_export/topic_exporter"

module ImportExport
  class CategoryExporter < BaseExporter

    def initialize(category_id)
      @category = Category.find(category_id)
      @categories = Category.where(parent_category_id: category_id).to_a
      @categories << @category
      @export_data = {
        categories: [],
        groups: [],
        topics: [],
        users: []
      }
    end

    def perform
      puts "Exporting category #{@category.name}...", ""
      export_categories!
      export_category_groups!
      export_topics_and_users
      self
    end

    def export_topics_and_users
      all_category_ids = @categories.pluck(:id)
      description_topic_ids = @categories.pluck(:topic_id)
      topic_exporter = ImportExport::TopicExporter.new(Topic.where(category_id: all_category_ids).pluck(:id) - description_topic_ids)
      topic_exporter.perform
      @export_data[:users]  = topic_exporter.export_data[:users]
      @export_data[:topics] = topic_exporter.export_data[:topics]
      self
    end

    def default_filename_prefix
      "category-export"
    end

  end
end
