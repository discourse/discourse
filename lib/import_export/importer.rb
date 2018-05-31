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

      @categories.reject! { |c| existing_category_ids.include? c[:id].to_s }
      @categories.sort_by! { |c| c[:parent_category_id].presence || 0 }

      @categories.each do |cat_attrs|
        begin
          id = cat_attrs.delete(:id)
          permissions = cat_attrs.delete(:permissions_params)

          category = Category.new(cat_attrs)
          category.parent_category_id = new_category_id(cat_attrs[:parent_category_id]) if cat_attrs[:parent_category_id].present?
          category.user_id = new_user_id(cat_attrs[:user_id])
          import_id = "#{id}#{import_source}"
          category.custom_fields["import_id"] = import_id
          category.permissions = permissions.present? ? permissions : { "everyone" => CategoryGroup.permission_types[:full] }
          category.save!
          existing_categories << { category_id: category.id, value: import_id }

          if cat_attrs[:description].present?
            post = category.topic.ordered_posts.first
            post.raw = cat_attrs[:description]
            post.save!
            post.rebake!
          end
        rescue
          next
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

  end
end
