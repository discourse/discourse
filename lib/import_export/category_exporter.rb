module ImportExport
  class CategoryExporter

    attr_reader :export_data

    def initialize(category_id)
      @category = Category.find(category_id)
      @subcategories = Category.where(parent_category_id: category_id)
      @export_data = {
        users: [],
        category: nil,
        subcategories: [],
        topics: []
      }
    end

    def perform
      puts "Exporting category #{@category.name}...", ""
      export_categories
      export_topics_and_users
      self
    end


    CATEGORY_ATTRS = [:id, :name, :color, :created_at, :user_id, :slug, :description, :text_color,
                      :auto_close_hours, :logo_url, :background_url, :auto_close_based_on_last_post,
                      :topic_template, :suppress_from_homepage]

    def export_categories
      # description
      @export_data[:category] = CATEGORY_ATTRS.inject({}) { |h,a| h[a] = @category.send(a); h }
      @subcategories.find_each do |subcat|
        @export_data[:subcategories] << CATEGORY_ATTRS.inject({}) { |h,a| h[a] = subcat.send(a); h }
      end
      self
    end

    def export_topics_and_users
      all_category_ids = [@category.id] + @subcategories.pluck(:id)
      description_topic_ids = Category.where(id: all_category_ids).pluck(:topic_id)
      topic_exporter = ImportExport::TopicExporter.new(Topic.where(category_id: all_category_ids).pluck(:id) - description_topic_ids)
      topic_exporter.perform
      @export_data[:users]  = topic_exporter.export_data[:users]
      @export_data[:topics] = topic_exporter.export_data[:topics]
      self
    end

    def save_to_file(filename=nil)
      require 'json'
      output_basename = filename || File.join("category-export-#{Time.now.strftime("%Y-%m-%d-%H%M%S")}.json")
      File.open(output_basename, "w:UTF-8") do |f|
        f.write(@export_data.to_json)
      end
      puts "Export saved to #{output_basename}"
      output_basename
    end

  end
end
