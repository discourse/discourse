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
        existing = User.where(email: u[:email]).first
        if existing && existing.custom_fields["import_id"] != u[:id]
          existing.custom_fields["import_id"] = u[:id]
          existing.save!
        else
          u = create_user(u, u[:id]) # see ImportScripts::Base
        end
      end
      self
    end

    def import_topics
      @export_data[:topics].each do |t|
        puts ""
        print t[:title]

        first_post_attrs = t[:posts].first.merge( t.slice(*(TopicExporter::TOPIC_ATTRS - [:id, :category_id])) )
        first_post_attrs[:user_id] = new_user_id(first_post_attrs[:user_id])
        first_post_attrs[:category] = new_category_id(t[:category_id])

        first_post = create_post( first_post_attrs, first_post_attrs[:id] )
        topic_id = first_post.topic_id
        t[:posts].each_with_index do |post_data, i|
          next if i == 0
          print "."
          create_post(post_data.merge({
            topic_id: topic_id,
            user_id: new_user_id(post_data[:user_id])
          }), post_data[:id]) # see ImportScripts::Base
        end
      end

      puts ""

      self
    end

    def new_user_id(external_user_id)
      ucf = UserCustomField.where(name: "import_id", value: external_user_id.to_s).first
      ucf ? ucf.user_id : Discourse::SYSTEM_USER_ID
    end

    def new_category_id(external_category_id)
      CategoryCustomField.where(name: "import_id", value: external_category_id).first.category_id rescue nil
    end
  end
end
