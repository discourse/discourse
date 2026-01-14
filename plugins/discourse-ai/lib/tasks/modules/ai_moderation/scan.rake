# frozen_string_literal: true

desc "Scan first posts of topics from a date, end date is optional. Usage: rake ai:spam:scan_topics[2024-01-01,2024-02-31]"
task "ai:spam:scan_topics", %i[start_date end_date] => [:environment] do |_, args|
  start_date = args[:start_date] ? DateTime.parse(args[:start_date]) : 1.day.ago
  end_date = args[:end_date] ? DateTime.parse(args[:end_date]) : Time.current

  scope = Topic.joins(:posts).where(created_at: start_date..end_date).where("posts.post_number = 1")
  puts "Processing #{scope.count} topics from #{start_date} to #{end_date}"
  scope
    .select("topics.id, posts.id as post_id")
    .find_each(batch_size: 500) do |record|
      Jobs.enqueue(:ai_spam_scan, post_id: record.post_id)
      print "."
    end
end

desc "Scan posts from a date, end date is optional. Usage: rake ai:spam:scan_posts[2024-01-31,2024-02-01]"
task "ai:spam:scan_posts", %i[start_date end_date] => [:environment] do |_, args|
  start_date = args[:start_date] ? DateTime.parse(args[:start_date]) : 1.day.ago
  end_date = args[:end_date] ? DateTime.parse(args[:end_date]) : Time.current

  scope = Post.where(created_at: start_date..end_date).select(:id)
  puts "Processing #{scope.count} posts from #{start_date} to #{end_date}"
  scope.find_each(batch_size: 500) do |post|
    Jobs.enqueue(:ai_spam_scan, post_id: post.id)
    print "."
  end
end
