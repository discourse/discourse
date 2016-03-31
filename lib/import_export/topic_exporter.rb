module ImportExport
  class TopicExporter

    attr_reader :exported_user_ids, :export_data

    def initialize(topic_ids)
      @topic_ids = topic_ids
      @exported_user_ids = []
      @export_data = {
        users: [],
        topics: []
      }
    end

    def perform
      export_users
      export_topics
      # TODO: user actions

      self
    end


    USER_ATTRS = [:id, :email, :username, :name, :created_at, :trust_level, :active, :last_emailed_at]

    def export_users
      # TODO: avatar

      @exported_user_ids = []
      @topic_ids.each do |topic_id|
        t = Topic.find(topic_id)
        t.posts.includes(user: [:user_profile]).find_each do |post|
          u = post.user
          unless @exported_user_ids.include?(u.id)
            x = USER_ATTRS.inject({}) { |h, a| h[a] = u.send(a); h; }
            @export_data[:users] << x.merge({
              bio_raw: u.user_profile.bio_raw,
              website: u.user_profile.website,
              location: u.user_profile.location
            })
            @exported_user_ids << u.id
          end
        end
      end

      self
    end


    def export_topics
      @topic_ids.each do |topic_id|
        t = Topic.find(topic_id)
        puts t.title
        export_topic(t)
      end
      puts ""
    end


    TOPIC_ATTRS = [:id, :title, :created_at, :views, :category_id, :closed, :archived, :archetype]
    POST_ATTRS = [:id, :user_id, :post_number, :raw, :created_at, :reply_to_post_number,
                  :hidden, :hidden_reason_id, :wiki]

    def export_topic(topic)
      topic_data = {}

      TOPIC_ATTRS.each do |a|
        topic_data[a] = topic.send(a)
      end

      topic_data[:posts] = []

      topic.ordered_posts.find_each do |post|
        h = POST_ATTRS.inject({}) { |h, a| h[a] = post.send(a); h; }
        h[:raw] = h[:raw].gsub('src="/uploads', "src=\"#{Discourse.base_url_no_prefix}/uploads")
        topic_data[:posts] << h
      end

      @export_data[:topics] << topic_data

      self
    end


    def save_to_file(filename=nil)
      require 'json'
      output_basename = filename || File.join("topic-export-#{Time.now.strftime("%Y-%m-%d-%H%M%S")}.json")
      File.open(output_basename, "w:UTF-8") do |f|
        f.write(@export_data.to_json)
      end
      puts "Export saved to #{output_basename}"
      output_basename
    end

  end
end
