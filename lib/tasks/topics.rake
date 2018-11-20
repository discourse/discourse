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

def update_static_page_topic(locale, site_setting_key, title_key, body_key, params = {})
  topic = Topic.find(SiteSetting.send(site_setting_key))

  if (topic && post = topic.first_post)
    post.revise(Discourse.system_user,
                title: I18n.t(title_key, locale: locale),
                raw: I18n.t(body_key, params.merge(locale: locale)))

    puts "", "Topic for #{site_setting_key} updated"
  else
    puts "", "Topic for #{site_setting_key} not found"
  end
end

desc "Update static topics (ToS, Privacy, Guidelines) with latest translated content"
task "topics:update_static", [:locale] => [:environment] do |_, args|
  locale = args[:locale]&.to_sym

  if locale.blank? || !I18n.locale_available?(locale)
    puts "ERROR: Expecting rake topics:update_static[locale]"
    exit 1
  end

  update_static_page_topic(locale, "tos_topic_id", "tos_topic.title", "tos_topic.body",
                           company_name: SiteSetting.company_name.presence || "company_name",
                           base_url: Discourse.base_url,
                           contact_email: SiteSetting.contact_email.presence || "contact_email",
                           governing_law: SiteSetting.governing_law.presence || "governing_law",
                           city_for_disputes: SiteSetting.city_for_disputes.presence || "city_for_disputes")

  update_static_page_topic(locale, "guidelines_topic_id", "guidelines_topic.title", "guidelines_topic.body",
                           base_path: Discourse.base_path)

  update_static_page_topic(locale, "privacy_topic_id", "privacy_topic.title", "privacy_topic.body")
end
