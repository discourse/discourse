# frozen_string_literal: true

module ImportExport
  class BaseExporter
    attr_reader :export_data

    CATEGORY_ATTRS = %i[
      id
      name
      color
      created_at
      user_id
      slug
      description
      text_color
      auto_close_hours
      position
      parent_category_id
      auto_close_based_on_last_post
      topic_template
      all_topics_wiki
      permissions_params
    ].freeze

    GROUP_ATTRS = %i[
      id
      name
      created_at
      automatic_membership_email_domains
      primary_group
      title
      grant_trust_level
      incoming_email
      bio_raw
      allow_membership_requests
      full_name
      default_notification_level
      visibility_level
      public_exit
      public_admission
      membership_request_template
      messageable_level
      mentionable_level
      members_visibility_level
      publish_read_state
    ].freeze

    USER_ATTRS = %i[
      id
      email
      username
      name
      created_at
      trust_level
      active
      last_emailed_at
      custom_fields
    ].freeze

    TOPIC_ATTRS = %i[id title created_at views category_id closed archived archetype].freeze

    POST_ATTRS = %i[
      id
      user_id
      post_number
      raw
      created_at
      reply_to_post_number
      hidden
      hidden_reason_id
      wiki
    ].freeze

    def categories
      @categories ||= Category.all.to_a
    end

    def export_categories
      data = []

      categories.each do |cat|
        data << CATEGORY_ATTRS.inject({}) do |h, a|
          h[a] = cat.public_send(a)
          h
        end
      end

      data
    end

    def export_categories!
      @export_data[:categories] = export_categories

      self
    end

    def export_groups(group_names)
      data = []
      groups = Group.all
      groups = groups.where(name: group_names) if group_names.present?

      groups.find_each do |group|
        attrs =
          GROUP_ATTRS.inject({}) do |h, a|
            h[a] = group.public_send(a)
            h
          end
        attrs[:user_ids] = group.users.pluck(:id)
        data << attrs
      end

      data
    end

    def export_groups!
      @export_data[:groups] = export_groups([])

      self
    end

    def export_category_groups
      groups = []
      group_names = []
      auto_group_names = Group::AUTO_GROUPS.keys.map(&:to_s)

      @export_data[:categories].each do |c|
        c[:permissions_params].each do |group_name, _|
          group_names << group_name if auto_group_names.exclude?(group_name.to_s)
        end
      end

      group_names.uniq!
      return [] if group_names.empty?

      export_groups(group_names)
    end

    def export_category_groups!
      @export_data[:groups] = export_category_groups

      self
    end

    def export_group_users
      user_ids = []

      @export_data[:groups].each { |g| user_ids += g[:user_ids] }

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

        topic_data =
          TOPIC_ATTRS.inject({}) do |h, a|
            h[a] = topic.public_send(a)
            h
          end

        topic_data[:posts] = []

        topic.ordered_posts.find_each do |post|
          attributes =
            POST_ATTRS.inject({}) do |h, a|
              h[a] = post.public_send(a)
              h
            end

          attributes[:raw] = attributes[:raw].gsub(
            'src="/uploads',
            "src=\"#{Discourse.base_url_no_prefix}/uploads",
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

      users = User.joins(:posts).where("posts.topic_id IN (?)", topic_ids).distinct

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

        x =
          USER_ATTRS.inject({}) do |h, a|
            h[a] = u.public_send(a)
            h
          end

        x.merge(
          bio_raw: u.user_profile.bio_raw,
          website: u.user_profile.website,
          location: u.user_profile.location,
        )
        data << x
      end

      data
    end

    def export_translation_overrides
      @export_data[:translation_overrides] = TranslationOverride.all.select(
        :locale,
        :translation_key,
        :value,
      )

      self
    end

    def default_filename_prefix
      raise "Overwrite me!"
    end

    def save_to_file(filename = nil)
      output_basename =
        filename ||
          File.join("#{default_filename_prefix}-#{Time.now.strftime("%Y-%m-%d-%H%M%S")}.json")
      File.open(output_basename, "w:UTF-8") { |f| f.write(@export_data.to_json) }
      puts "Export saved to #{output_basename}"
      output_basename
    end
  end
end
