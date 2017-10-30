require File.join(Rails.root, 'script', 'import_scripts', 'base.rb')

module ImportExport
  class TopicImporter < ImportScripts::Base
    def initialize(export_data)
      @export_data = export_data
    end

    def perform
      RateLimiter.disable

      import_users
      import_topics
      self
    ensure
      RateLimiter.enable
    end

    def import_users
      @export_data[:users].each do |u|
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

    def import_topics
      @export_data[:topics].each do |t|
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
      CategoryCustomField.where(name: "import_id", value: "#{external_category_id}#{import_source}").first.category_id rescue nil
    end

    def import_source
      @_import_source ||= "#{ENV['IMPORT_SOURCE'] || ''}"
    end
  end
end
