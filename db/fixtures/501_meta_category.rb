unless Rails.env.test?
  meta = Category.find_by(id: SiteSetting.meta_category_id)
  if meta && !meta.topic_id

    Category.transaction do
      creator = PostCreator.new(Discourse.system_user,
        raw: I18n.t('meta_category_description'),
        title: I18n.t('category.topic_prefix', category: meta.name),
        category: meta.name,
        archetype: Archetype.default
      )
      post = creator.create

      unless post && post.id
        puts post.errors.full_messages if post
        puts creator.errors.inspect
        raise "Failed meta topic"
      end

      meta.set_permissions(:everyone => :full)
      meta.topic_id = post.topic.id
      unless meta.save
        puts meta.errors.full_messages
        puts "Failed to set the meta description and permission!"
      end

      # Reset topic count because we don't count the description topic
      Category.exec_sql "UPDATE categories SET topic_count = 0 WHERE id = #{meta.id}"
    end
  end
end
