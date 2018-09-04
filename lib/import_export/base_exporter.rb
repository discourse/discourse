module ImportExport
  class BaseExporter

    attr_reader :export_data, :categories

    CATEGORY_ATTRS = [:id, :name, :color, :created_at, :user_id, :slug, :description, :text_color,
                      :auto_close_hours, :parent_category_id, :auto_close_based_on_last_post,
                      :topic_template, :suppress_from_latest, :all_topics_wiki, :permissions_params]

    GROUP_ATTRS = [ :id, :name, :created_at, :mentionable_level, :messageable_level, :visibility_level,
                    :automatic_membership_email_domains, :automatic_membership_retroactive,
                    :primary_group, :title, :grant_trust_level, :incoming_email]

    USER_ATTRS = [:id, :email, :username, :name, :created_at, :trust_level, :active, :last_emailed_at]

    TOPIC_ATTRS = [:id, :title, :created_at, :views, :category_id, :closed, :archived, :archetype]

    POST_ATTRS = [:id, :user_id, :post_number, :raw, :created_at, :reply_to_post_number, :hidden,
                  :hidden_reason_id, :wiki]

    def categories
      @categories ||= Category.all.to_a
    end

    def export_categories
      data = []

      categories.each do |cat|
        data << CATEGORY_ATTRS.inject({}) { |h, a| h[a] = cat.send(a); h }
      end

      data
    end

    def export_categories!
      @export_data[:categories] = export_categories

      self
    end

    def export_category_groups
      groups = []
      group_names = []
      auto_group_names = Group::AUTO_GROUPS.keys.map(&:to_s)

      @export_data[:categories].each do |c|
        c[:permissions_params].each do |group_name, _|
          group_names << group_name unless auto_group_names.include?(group_name.to_s)
        end
      end

      group_names.uniq!
      return [] if group_names.empty?

      Group.where(name: group_names).find_each do |group|
        attrs = GROUP_ATTRS.inject({}) { |h, a| h[a] = group.send(a); h }
        attrs[:user_ids] = group.users.pluck(:id)
        groups << attrs
      end

      groups
    end

    def export_category_groups!
      @export_data[:groups] = export_category_groups

      self
    end

    def export_group_users
      user_ids = []

      @export_data[:groups].each do |g|
        user_ids += g[:user_ids]
      end

      user_ids.uniq!
      return User.none if user_ids.empty?

      users = User.where(id: user_ids)
      export_users(users)
    end

    def export_group_users!
      @export_data[:users] = export_group_users

      self
    end

    def export_topics
      data = []

      @topics.each do |topic|
        puts topic.title

        topic_data = TOPIC_ATTRS.inject({}) { |h, a| h[a] = topic.send(a); h; }
        topic_data[:posts] = []

        topic.ordered_posts.find_each do |post|
          attributes = POST_ATTRS.inject({}) { |h, a| h[a] = post.send(a); h; }

          attributes[:raw] = attributes[:raw].gsub(
            'src="/uploads',
            "src=\"#{Discourse.base_url_no_prefix}/uploads"
          )

          topic_data[:posts] << attributes
        end

        data << topic_data
      end

      data
    end

    def export_topics!
      @export_data[:topics] = export_topics

      self
    end

    def export_topic_users
      return if @export_data[:topics].blank?
      topic_ids = @export_data[:topics].pluck(:id)

      users = User.joins(:posts).where('posts.topic_id IN (?)', topic_ids).distinct

      export_users(users)
    end

    def export_topic_users!
      @export_data[:users] = export_topic_users

      self
    end

    def export_users(users)
      data = []

      users.find_each do |u|
        next if u.id == Discourse::SYSTEM_USER_ID
        x = USER_ATTRS.inject({}) { |h, a| h[a] = u.send(a); h; }
        x.merge(bio_raw: u.user_profile.bio_raw,
                website: u.user_profile.website,
                location: u.user_profile.location)
        data << x
      end

      data
    end

    def default_filename_prefix
      raise "Overwrite me!"
    end

    def save_to_file(filename = nil)
      output_basename = filename || File.join("#{default_filename_prefix}-#{Time.now.strftime("%Y-%m-%d-%H%M%S")}.json")
      File.open(output_basename, "w:UTF-8") do |f|
        f.write(@export_data.to_json)
      end
      puts "Export saved to #{output_basename}"
      output_basename
    end

  end
end
