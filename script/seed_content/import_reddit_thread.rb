# frozen_string_literal: true

# Reddit Thread Importer for Discourse Rails Console
# Paste this entire script into `rails c` to define the import method.
#
# Usage:
#   import_reddit("https://www.reddit.com/r/IAmA/comments/109eze3/...")
#   import_reddit("https://www.reddit.com/r/IAmA/comments/109eze3/...", category_id: 5)
#
#   # Batch import:
#   urls = %w[
#     https://www.reddit.com/r/programming/comments/abc123/...
#     https://www.reddit.com/r/ruby/comments/def456/...
#   ]
#   urls.each { |url| import_reddit(url, category_id: 5) }

require "net/http"
require "json"

def import_reddit(url, category_id: SiteSetting.uncategorized_category_id)
  # -- Step 1: Fetch the thread from Reddit API --

  base_url =
    url
      .sub(%r{https?://(old|new|www|np)\.reddit\.com}, "https://www.reddit.com")
      .sub(/\?.*$/, "")
      .chomp("/")

  uri = URI("#{base_url}.json?sort=top&limit=500&raw_json=1")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 15
  http.read_timeout = 30
  request = Net::HTTP::Get.new(uri)
  request["User-Agent"] = "discourse:thread_import:v1.0"

  response = http.request(request)
  raise "HTTP #{response.code}: #{response.body[0..200]}" unless response.is_a?(Net::HTTPSuccess)

  data = JSON.parse(response.body)
  post_data = data[0]["data"]["children"][0]["data"]

  # Flatten the nested comment tree (BFS so parents are always created before children)
  comments = []
  queue = (data[1]["data"]["children"] || []).dup
  more_count = 0

  while queue.any?
    node = queue.shift

    if node["kind"] == "more"
      more_count += (node.dig("data", "children") || []).size
      next
    end

    next if node["kind"] != "t1"

    c = node["data"]
    next if c["author"].blank? || c["author"] == "[deleted]"
    next if c["body"].blank? || c["body"] == "[deleted]" || c["body"] == "[removed]"

    comments << c

    if c["replies"].is_a?(Hash)
      children = c["replies"]["data"]["children"]
      queue.concat(children) if children
    end
  end

  puts "\n  Post:     #{post_data["title"]}"
  puts "  Comments: #{comments.size} (#{more_count} more behind Reddit's fold)"
  puts "  Users:    #{comments.map { |cm| cm["author"] }.uniq.size + 1}"

  # -- Step 2: Create staged users --

  usernames = ([post_data["author"]] + comments.map { |cm| cm["author"] }).compact.uniq
  usernames.reject! { |u| u == "[deleted]" }
  users = {}

  usernames.each do |username|
    existing = User.find_by(username: username)
    if existing
      users[username] = existing
      next
    end

    user =
      User.new(
        username: username,
        email: "#{username.downcase}@reddit.import",
        password: SecureRandom.hex(20),
        staged: true,
        active: true,
      )
    user.skip_email_validation = true
    user.save!(validate: false)
    users[username] = user
  end

  puts "  Staged users ready."

  # -- Step 3: Create the topic --

  story_user = users[post_data["author"]] || Discourse.system_user
  story_raw = +""
  if post_data["url"].present? && !post_data["is_self"]
    story_raw << "[#{post_data["title"]}](#{post_data["url"]})\n\n"
  end
  story_raw << post_data["selftext"] if post_data["selftext"].present?
  story_raw = post_data["title"] if story_raw.blank?

  topic_post =
    PostCreator.new(
      story_user,
      title: post_data["title"][0..254],
      raw: story_raw,
      category: category_id,
      created_at: Time.at(post_data["created_utc"].to_i),
      skip_validations: true,
      import_mode: true,
    ).create!

  topic_post.update_columns(like_count: post_data["score"].to_i) if post_data["score"].to_i > 0

  puts "  Created topic ##{topic_post.topic_id} (score: #{post_data["score"]})"

  # -- Step 4: Create comments with threading --

  # Reddit parent_id uses fullnames: t3_xxxxx (reply to post) or t1_xxxxx (reply to comment)
  reddit_id_to_post = { post_data["name"] => topic_post }

  comments.each_with_index do |comment, idx|
    user = users[comment["author"]] || Discourse.system_user
    parent_post = reddit_id_to_post[comment["parent_id"]]

    opts = {
      topic_id: topic_post.topic_id,
      raw: comment["body_html"],
      created_at: Time.at(comment["created_utc"].to_i),
      skip_validations: true,
      import_mode: true,
      cook_method: Post.cook_methods[:raw_html],
    }

    if parent_post && parent_post.post_number > 1
      opts[:reply_to_post_number] = parent_post.post_number
    end

    post = PostCreator.new(user, opts).create!
    reddit_id_to_post["t1_#{comment["id"]}"] = post

    post.update_columns(like_count: comment["score"].to_i) if comment["score"].to_i > 0

    print "\r  Posts: #{idx + 1}/#{comments.size}"
  rescue => e
    puts "\n  ERROR on comment #{comment["id"]}: #{e.message}"
  end

  topic = topic_post.topic
  topic.update_columns(bumped_at: topic_post.created_at, updated_at: topic_post.created_at)

  topic_url = "#{Discourse.base_url}/t/#{topic.slug}/#{topic.id}"
  puts "\n\nDone! #{reddit_id_to_post.size} posts created."
  puts "URL: #{topic_url}"

  topic_url
end
