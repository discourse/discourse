require "import_export/category_exporter"
require "import_export/category_importer"
require "import_export/topic_exporter"
require "import_export/topic_importer"
require "json"

module ImportExport

  def self.export_category(category_id, filename=nil)
    ImportExport::CategoryExporter.new(category_id).perform.save_to_file(filename)
  end

  def self.import_category(filename)
    export_data = ActiveSupport::HashWithIndifferentAccess.new(File.open(filename, "r:UTF-8") { |f| JSON.parse(f.read) })
    ImportExport::CategoryImporter.new(export_data).perform
  end

  def self.export_topics(topic_ids)
    ImportExport::TopicExporter.new(topic_ids).perform.save_to_file
  end

  def self.import_topics(filename)
    export_data = ActiveSupport::HashWithIndifferentAccess.new(File.open(filename, "r:UTF-8") { |f| JSON.parse(f.read) })
    ImportExport::TopicImporter.new(export_data).perform
  end
end
