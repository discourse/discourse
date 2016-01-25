require File.join(Rails.root, 'script', 'import_scripts', 'base.rb')

module ImportExport
  class CategoryImporter < ImportScripts::Base
    def initialize(export_data)
      @export_data = export_data
      @topic_importer = TopicImporter.new(@export_data)
    end

    def perform
      RateLimiter.disable

      import_users
      import_categories
      import_topics
      self
    ensure
      RateLimiter.enable
    end

    def import_users
      @topic_importer.import_users
    end

    def import_categories
      id = @export_data[:category].delete(:id)
      parent = Category.new(@export_data[:category])
      parent.user_id = @topic_importer.new_user_id(@export_data[:category][:user_id]) # imported user's new id
      parent.custom_fields["import_id"] = id
      parent.save!
      set_category_description(parent, @export_data[:category][:description])

      @export_data[:subcategories].each do |cat_attrs|
        id = cat_attrs.delete(:id)
        subcategory = Category.new(cat_attrs)
        subcategory.parent_category_id = parent.id
        subcategory.user_id = @topic_importer.new_user_id(cat_attrs[:user_id])
        subcategory.custom_fields["import_id"] = id
        subcategory.save!
        set_category_description(subcategory, cat_attrs[:description])
      end
    end

    def set_category_description(c, description)
      post = c.topic.ordered_posts.first
      post.raw = description
      post.save!
      post.rebake!
    end

    def import_topics
      @topic_importer.import_topics
    end
  end
end
