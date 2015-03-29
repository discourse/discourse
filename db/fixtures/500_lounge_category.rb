unless Rails.env.test?
  lounge = Category.find_by(id: SiteSetting.lounge_category_id)
  if lounge and !lounge.group_ids.include?(Group[:trust_level_3].id)

    # The category for users with trust level 3 has been created.
    # Add permissions and a description to it.

    Category.transaction do
      lounge.group_names = ['trust_level_3']
      unless lounge.save
        puts lounge.errors.full_messages
        raise "Failed to set permissions on trust level 3 lounge category!"
      end

      if lounge.topic_id.nil?
        creator = PostCreator.new(Discourse.system_user,
          raw: I18n.t('vip_category_description'),
          title: I18n.t('category.topic_prefix', category: lounge.name),
          category: lounge.name,
          archetype: Archetype.default,
          skip_validations: true
        )
        post = creator.create

        unless post && post.id
          puts post.errors.full_messages if post
          puts creator.errors.inspect
          raise "Failed to create description for trust level 3 lounge!"
        end

        lounge.topic_id = post.topic.id
        unless lounge.save
          puts lounge.errors.full_messages
          puts "Failed to set the lounge description topic!"
        end

        # Reset topic count because we don't count the description topic
        Category.exec_sql "UPDATE categories SET topic_count = 0 WHERE id = #{lounge.id}"
      end
    end
  end
end
