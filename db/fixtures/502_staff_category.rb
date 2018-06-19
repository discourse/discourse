unless Rails.env.test?
  staff = Category.find_by(id: SiteSetting.staff_category_id)
  if staff && !staff.group_ids.include?(Group[:staff].id)

    # Add permissions and a description to the Staff category.

    Category.transaction do
      staff.group_names = ['staff']
      unless staff.save
        puts staff.errors.full_messages
        raise "Failed to set permissions on the Staff category!"
      end

      if staff.topic_id.nil?
        creator = PostCreator.new(Discourse.system_user,
          raw: I18n.t('staff_category_description'),
          title: I18n.t('category.topic_prefix', category: staff.name),
          category: staff.name,
          archetype: Archetype.default
        )
        post = creator.create

        unless post && post.id
          puts post.errors.full_messages if post
          puts creator.errors.inspect
          raise "Failed to create description for Staff category!"
        end

        staff.topic_id = post.topic.id
        unless staff.save
          puts staff.errors.full_messages
          puts "Failed to set the Staff category description topic!"
        end

        # Reset topic count because we don't count the description topic
        DB.exec "UPDATE categories SET topic_count = 0 WHERE id = #{staff.id}"
      end
    end
  end
end
