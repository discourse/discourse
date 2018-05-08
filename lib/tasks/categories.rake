task "categories:move_topics", [:from_category, :to_category] => [:environment] do |_, args|
  from_category_id = args[:from_category]
  to_category_id = args[:to_category]

  if !from_category_id || !to_category_id
    puts "ERROR: Expecting categories:move_topics[from_category_id,to_category_id]"
    exit 1
  end

  from_category = Category.find(from_category_id)
  to_category = Category.find(to_category_id)

  if from_category && to_category
    Topic.where(category_id: from_category_id).update_all(category_id: to_category_id)
    from_category.update_attribute(:topic_count, 0)
    Category.update_stats
  end

  puts "", "Done!", ""
end
