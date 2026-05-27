# frozen_string_literal: true

desc "Backfill empty excerpts for topic localizations from post localizations"
task "topic_localizations:backfill_excerpts" => :environment do
  updated = 0
  scope =
    TopicLocalization
      .where(excerpt: [nil, ""])
      .joins(:topic)
      .where.not(topics: { excerpt: "" })
      .includes(topic: { first_post: :localizations })

  total = scope.count
  puts "Found #{total} topic localizations to process"
  next if total == 0

  scope.find_each do |topic_localization|
    post_localization =
      topic_localization.topic.first_post&.localizations&.find_by(locale: topic_localization.locale)

    if post_localization
      topic_localization.update_excerpt(cooked: post_localization.cooked)
      updated += 1
    end

    print "\r#{updated}/#{total} processed"
  end
  puts "\nDone! Updated #{updated} topic localizations."
end
