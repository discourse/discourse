# frozen_string_literal: true

require File.join(Rails.root, 'script', 'import_scripts', 'base.rb')

module ImportExport
  class Importer < ImportScripts::Base

    def initialize(data)
      @users = data[:users]
      @groups = data[:groups]
      @categories = data[:categories]
      @topics = data[:topics]

      # To support legacy `category_export` script
      if data[:category].present?
        @categories = [] if @categories.blank?
        @categories << data[:category]
      end
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

    def import_users
      return if @users.blank?

      puts "Importing users..."

      @users.each do |u|
        import_id = "#{u[:id]}#{import_source}"
        existing = User.with_email(u[:email]).first

        if existing
          if existing.custom_fields["import_id"] != import_id
            existing.custom_fields["import_id"] = import_id
            existing.save!
          end
        else
          u = create_user(u, import_id) # see ImportScripts::Base
        end
      end

      self
    end

    def import_groups
      return if @groups.blank?

      puts "Importing groups..."

      @groups.each do |group_data|
        g = group_data.dup
        user_ids = g.delete(:user_ids)
        external_id = g.delete(:id)
        new_group = Group.find_by_name(g[:name]) || Group.create!(g)
        user_ids.each do |external_user_id|
          new_group.add(User.find(new_user_id(external_user_id))) rescue ActiveRecord::RecordNotUnique
        end
      end

      self
    end

    def import_categories
      return if @categories.blank?

      puts "Importing categories..."

      import_ids = @categories.collect { |c| "#{c[:id]}#{import_source}" }
      existing_categories = CategoryCustomField.where("name = 'import_id' AND value IN (?)", import_ids).select(:category_id, :value).to_a
      existing_category_ids = existing_categories.pluck(:value)

      levels = category_levels
      max_level = levels.values.max
      if SiteSetting.max_category_nesting < max_level
        puts "Setting max_category_nesting to #{max_level}..."
        SiteSetting.max_category_nesting = max_level
      end

      fix_permissions

      @categories.reject! { |c| existing_category_ids.include? c[:id].to_s }
      @categories.sort_by! { |c| levels[c[:id]] || 0 }

      @categories.each do |cat_attrs|
        begin
          id = cat_attrs.delete(:id)
          permissions = cat_attrs.delete(:permissions_params)

          category = Category.new(cat_attrs)
          category.parent_category_id = new_category_id(cat_attrs[:parent_category_id]) if cat_attrs[:parent_category_id].present?
          category.user_id = new_user_id(cat_attrs[:user_id])
          import_id = "#{id}#{import_source}"
          category.custom_fields["import_id"] = import_id
          category.permissions = permissions
          category.save!
          existing_categories << { category_id: category.id, value: import_id }

          if cat_attrs[:description].present?
            post = category.topic.ordered_posts.first
            post.raw = cat_attrs[:description]
            post.skip_validation = true
            post.save!
            post.rebake!
          end
        rescue => e
          puts "Failed to import category (ID = #{id}, name = #{cat_attrs[:name]}): #{e.message}"
        end
      end

      self
    end

    def import_topics
      return if @topics.blank?

      puts "Importing topics...", ''

      @topics.each do |t|
        puts ""
        print t[:title]

        first_post_attrs = t[:posts].first.merge(t.slice(*(TopicExporter::TOPIC_ATTRS - [:id, :category_id])))

        first_post_attrs[:user_id] = new_user_id(first_post_attrs[:user_id])
        first_post_attrs[:category] = new_category_id(t[:category_id])

        import_id = "#{first_post_attrs[:id]}#{import_source}"
        first_post = PostCustomField.where(name: "import_id", value: import_id).first&.post

        unless first_post
          first_post = create_post(first_post_attrs, import_id)
        end

        topic_id = first_post.topic_id

        t[:posts].each_with_index do |post_data, i|
          next if i == 0
          print "."
          post_import_id = "#{post_data[:id]}#{import_source}"
          existing = PostCustomField.where(name: "import_id", value: post_import_id).first&.post
          unless existing
            # see ImportScripts::Base
            create_post(
              post_data.merge(
                topic_id: topic_id,
                user_id: new_user_id(post_data[:user_id])
              ),
              post_import_id
            )
          end
        end
      end

      puts ""

      self
    end

    def new_user_id(external_user_id)
      ucf = UserCustomField.where(name: "import_id", value: "#{external_user_id}#{import_source}").first
      ucf ? ucf.user_id : Discourse::SYSTEM_USER_ID
    end

    def new_category_id(external_category_id)
      CategoryCustomField.where(
        name: "import_id",
        value: "#{external_category_id}#{import_source}"
      ).first&.category_id
    end

    def import_source
      @_import_source ||= "#{ENV['IMPORT_SOURCE'] || ''}"
    end

    def category_levels
      @levels ||= begin
        levels = {}

        # Incomplete backups may lack definitions for some parent categories
        # which would cause an infinite loop below.
        parent_ids = @categories.map { |category| category[:parent_category_id] }.uniq
        category_ids = @categories.map { |category| category[:id] }.uniq
        (parent_ids - category_ids).each { |id| levels[id] = 0 }

        loop do
          changed = false

          @categories.each do |category|
            if !levels[category[:id]]
              if !category[:parent_category_id]
                levels[category[:id]] = 1
              elsif levels[category[:parent_category_id]]
                levels[category[:id]] = levels[category[:parent_category_id]] + 1
              end

              changed = true
            end
          end

          break if !changed
        end

        levels
      end
    end

    def fix_permissions
      categories_by_id = @categories.to_h { |category| [category[:id], category] }

      @categories.each do |category|
        if category[:permissions_params].blank?
          category[:permissions_params] = { "everyone" => CategoryGroup.permission_types[:full] }
        end
      end

      max_level = category_levels.values.max
      max_level.times do
        @categories.each do |category|
          parent_category = categories_by_id[category[:parent_category_id]]
          next if !parent_category || !parent_category[:permissions_params] || parent_category[:permissions_params][:everyone]

          parent_groups = parent_category[:permissions_params].map(&:first)
          child_groups = category[:permissions_params].map(&:first)

          only_subcategory_groups = child_groups - parent_groups
          if only_subcategory_groups.present?
            parent_category[:permissions_params].merge!(category[:permissions_params].slice(*only_subcategory_groups))
          end
        end
      end
    end
  end
end
