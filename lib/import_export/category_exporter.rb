module ImportExport
  class CategoryExporter

    attr_reader :export_data

    def initialize(category_id)
      @category = Category.find(category_id)
      @subcategories = Category.where(parent_category_id: category_id)
      @export_data = {
        users: [],
        groups: [],
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
                      :topic_template, :suppress_from_homepage, :permissions_params]

    def export_categories
      @export_data[:category] = CATEGORY_ATTRS.inject({}) { |h,a| h[a] = @category.send(a); h }
      @subcategories.find_each do |subcat|
        @export_data[:subcategories] << CATEGORY_ATTRS.inject({}) { |h,a| h[a] = subcat.send(a); h }
      end

      # export groups that are mentioned in category permissions
      group_names = []
      auto_group_names = Group::AUTO_GROUPS.keys.map(&:to_s)

      ([@export_data[:category]] + @export_data[:subcategories]).each do |c|
        c[:permissions_params].each do |group_name, _|
          group_names << group_name unless auto_group_names.include?(group_name.to_s)
        end
      end

      group_names.uniq!
      export_groups(group_names) unless group_names.empty?

      self
    end


    GROUP_ATTRS = [ :id, :name, :created_at, :alias_level, :visible,
                    :automatic_membership_email_domains, :automatic_membership_retroactive,
                    :primary_group, :title, :grant_trust_level, :incoming_email]

    def export_groups(group_names)
      group_names.each do |name|
        group = Group.find_by_name(name)
        group_attrs = GROUP_ATTRS.inject({}) { |h,a| h[a] = group.send(a); h }
        group_attrs[:user_ids] = group.users.pluck(:id)
        @export_data[:groups] << group_attrs
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
