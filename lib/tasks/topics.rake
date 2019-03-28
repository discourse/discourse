def print_status_with_label(label, current, max)
  print "\r%s%9d / %d (%5.1f%%)" % [label, current, max, ((current.to_f / max.to_f) * 100).round(1)]
end

def close_old_topics(category)
  topics = Topic.where(closed: false, category_id: category.id)

  if category.auto_close_based_on_last_post
    topics = topics.where('last_posted_at < ?', category.auto_close_hours.hours.ago)
  else
    topics = topics.where('created_at < ?', category.auto_close_hours.hours.ago)
  end

  topics_closed = 0
  total = topics.count

  if total == 0
    print "    all old topics are closed"
    return
  end

  topics.find_each do |topic|
    topic.update_status("closed", true, Discourse.system_user)
    print_status_with_label("    closing old topics: ", topics_closed += 1, total)
  end
end

def apply_auto_close(category)
  topics = Topic.where(closed: false, category_id: category.id)
    .where(<<-SQL, TopicTimer.types[:close])
      NOT EXISTS (
        SELECT 1
        FROM topic_timers
        WHERE topic_timers.topic_id = topics.id
          AND topic_timers.status_type = ?
          AND topic_timers.deleted_at IS NULL
      )
    SQL

  topics_closed = 0
  total = topics.count

  if total == 0
    print "    all topics have auto-close applied"
    return
  end

  topics.find_each do |topic|
    topic.inherit_auto_close_from_category
    print_status_with_label("    applying auto-close to topics: ", topics_closed += 1, total)
  end
end

task "topics:apply_autoclose" => :environment do
  categories = Category.where("auto_close_hours > 0")

  categories.find_each do |category|
    puts "", "Applying auto-close to category '#{category.name}' ..."
    close_old_topics(category)
    puts ""
    apply_auto_close(category)
    puts ""
  end

  puts "", "Done"
end
