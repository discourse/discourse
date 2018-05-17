task "categories:move_topics", [:from_category, :to_category] => [:environment] do |_, args|
  from_category_id = args[:from_category]
  to_category_id = args[:to_category]

  if !from_category_id || !to_category_id
    puts "ERROR: Expecting categories:move_topics[from_category_id,to_category_id]"
    exit 1
  end

  from_category = Category.find(from_category_id)
  to_category = Category.find(to_category_id)

  if from_category.present? && to_category.present?
    puts "Moving topics from #{from_category.slug} to #{to_category.slug}..."
    Topic.where(category_id: from_category.id).update_all(category_id: to_category.id)
    from_category.update_attribute(:topic_count, 0)

    puts "Updating category stats..."
    Category.update_stats
  end

  puts "", "Done!", ""
end
