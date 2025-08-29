# frozen_string_literal: true

require "rake_helpers"

def close_old_topics(category)
  topics = Topic.where(closed: false, category_id: category.id)

  if category.auto_close_based_on_last_post
    topics = topics.where("last_posted_at < ?", category.auto_close_hours.hours.ago)
  else
    topics = topics.where("created_at < ?", category.auto_close_hours.hours.ago)
  end

  topics_closed = 0
  total = topics.count

  if total == 0
    print "    all old topics are closed"
    return
  end

  topics.find_each do |topic|
    topic.update_status("closed", true, Discourse.system_user, { silent: true })
    RakeHelpers.print_status_with_label("    closing old topics: ", topics_closed += 1, total)
  end
end

def apply_auto_close(category)
  topics =
    Topic.where(closed: false, category_id: category.id).where(<<-SQL, TopicTimer.types[:close])
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
    RakeHelpers.print_status_with_label(
      "    applying auto-close to topics: ",
      topics_closed += 1,
      total,
    )
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

task "topics:watch_all_replied_topics" => :environment do
  puts "Setting all topics to Watching on which a user has posted at least once..."
  topics = Topic.where("archetype != ?", Archetype.private_message)
  total = topics.count
  count = 0

  topics.find_each do |t|
    t
      .topic_users
      .where(posted: true)
      .find_each do |tp|
        tp.update!(
          notification_level: TopicUser.notification_levels[:watching],
          notifications_reason_id: TopicUser.notification_reasons[:created_post],
        )
      end
    RakeHelpers.print_status(count += 1, total)
  end

  puts "", "Done"
end

task "topics:update_fancy_titles" => :environment do
  if !SiteSetting.title_fancy_entities?
    puts "fancy topic titles are disabled"
    next
  end

  DB.exec("UPDATE topics SET fancy_title = NULL")

  total = Topic.count
  count = 0

  Topic.find_each do |topic|
    topic.fancy_title
    RakeHelpers.print_status(count += 1, total)
  end

  puts "", "Done"
end

desc "Remap topic titles - replace a specific string with another"
task "topics:remap_titles", %i[old_string new_string] => [:environment] do |_, args|
  require "highline/import"

  if args[:old_string].blank? || args[:new_string].blank?
    puts "ERROR: Missing required arguments"
    puts "Usage: rake topics:remap_titles['old string','new string']"
    exit 1
  end

  old_string = args[:old_string]
  new_string = args[:new_string]

  # add a confirmation to ensure user wants to replace old with new here
  confirm_replace =
    ask(
      "Are you sure you want to replace all occurrences of '#{old_string}' with '#{new_string}' in topic titles? (Y/n)",
    )

  if confirm_replace.blank? || confirm_replace.downcase == "y"
    puts "Remapping topic titles..."
    puts "Replacing '#{old_string}' with '#{new_string}'"

    # Filter topics that contain the old_string (using LIKE for case-sensitive matching)
    matching_topics =
      Topic
        .where("title LIKE ?", "%#{old_string}%")
        .where("deleted_at IS NULL")
        .where(archetype: "regular")
        .where.not(title: nil)

    total_matches = matching_topics.count
    puts "Found #{total_matches} topics containing '#{old_string}'"

    if total_matches == 0
      puts "No matching topics found. Exiting."
      exit 0
    end

    count = 0
    matching_topics.find_each do |topic|
      old_title = topic.title
      new_title = topic.title.gsub(old_string, new_string)

      # Only update if there's an actual change
      if old_title != new_title
        puts "#{topic.id}: #{old_title} → #{new_title}"

        # Update the title directly with SQL
        Topic.where(id: topic.id).update_all(title: new_title, fancy_title: new_title)

        count += 1
      end
    end

    puts "Remapped #{count} topic titles."
  else
    puts "Aborting..."
    exit 0
  end
end
