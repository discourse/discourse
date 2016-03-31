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
      import_groups
      import_categories
      import_topics
      self
    ensure
      RateLimiter.enable
    end

    def import_groups
      return if @export_data[:groups].empty?

      @export_data[:groups].each do |group_data|
        g = group_data.dup
        user_ids = g.delete(:user_ids)
        external_id = g.delete(:id)
        new_group = Group.find_by_name(g[:name]) || Group.create!(g)
        user_ids.each do |external_user_id|
          new_group.add( User.find(@topic_importer.new_user_id(external_user_id)) ) rescue ActiveRecord::RecordNotUnique
        end
      end
    end

    def import_users
      @topic_importer.import_users
    end

    def import_categories
      id = @export_data[:category].delete(:id)

      parent = CategoryCustomField.where(name: 'import_id', value: id.to_s).first.try(:category)

      unless parent
        permissions = @export_data[:category].delete(:permissions_params)
        parent = Category.new(@export_data[:category])
        parent.user_id = @topic_importer.new_user_id(@export_data[:category][:user_id]) # imported user's new id
        parent.custom_fields["import_id"] = id
        parent.permissions = permissions if permissions
        parent.save!
        set_category_description(parent, @export_data[:category][:description])
      end

      @export_data[:subcategories].each do |cat_attrs|
        id = cat_attrs.delete(:id)
        existing = CategoryCustomField.where(name: 'import_id', value: id.to_s).first.try(:category)

        unless existing
          permissions = cat_attrs.delete(:permissions_params)
          subcategory = Category.new(cat_attrs)
          subcategory.parent_category_id = parent.id
          subcategory.user_id = @topic_importer.new_user_id(cat_attrs[:user_id])
          subcategory.custom_fields["import_id"] = id
          subcategory.permissions = permissions if permissions
          subcategory.save!
          set_category_description(subcategory, cat_attrs[:description])
        end
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
