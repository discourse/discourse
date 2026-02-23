# frozen_string_literal: true

# HN Thread Importer for Discourse Rails Console
# Paste this entire script into `rails c` to define the import method.
#
# Usage:
#   import_hn(8863)
#   import_hn(8863, category_id: 5)
#
#   # Batch import:
#   [8863, 12345, 67890].each { |id| import_hn(id, category_id: 3) }

require "net/http"
require "json"

def import_hn(hn_item_id, category_id: SiteSetting.uncategorized_category_id)
  # -- Step 1: Fetch the entire thread from HN API --

  hn_items = {}
  queue = [hn_item_id]

  retries = Hash.new(0)
  concurrency = 10
  delay = 0.1 # seconds between batches, increases on errors

  while queue.any?
    batch = queue.shift(concurrency)
    threads =
      batch.map do |id|
        Thread.new(id) do |item_id|
          uri = URI("https://hacker-news.firebaseio.com/v0/item/#{item_id}.json")
          response = Net::HTTP.get_response(uri)
          raise "HTTP #{response.code}" if response.code.to_i == 429 || response.code.to_i >= 500
          [item_id, JSON.parse(response.body)]
        rescue => e
          [item_id, nil, e.message]
        end
      end

    threads.each do |t|
      id, item, error = t.value
      if item
        hn_items[id] = item
        queue.concat(item["kids"] || [])
      elsif retries[id] < 3
        retries[id] += 1
        queue.unshift(id) # retry later
        delay = [delay * 2, 5.0].min # back off
        concurrency = [concurrency - 1, 2].max
      else
        puts "\n  WARN: giving up on item #{id} after 3 retries (#{error})"
      end
    end

    print "\r  Fetched #{hn_items.size} items... (delay: #{delay.round(1)}s, concurrency: #{concurrency})"
    sleep(delay)
    # ease back toward normal after a successful batch with no retries
    if threads.none? { |t| t.value[1].nil? }
      delay = [delay * 0.8, 0.1].max
      concurrency = [concurrency + 1, 10].min
    end
  end

  story = hn_items[hn_item_id]
  comments =
    hn_items
      .values
      .select { |i| i["type"] == "comment" && i["text"].present? && !i["dead"] && !i["deleted"] }
      .sort_by { |i| i["time"] }

  puts "\n  Story:    #{story["title"]}"
  puts "  Comments: #{comments.size}"
  puts "  Users:    #{comments.map { |c| c["by"] }.uniq.size + 1}"

  # -- Step 2: Create staged users --

  usernames = ([story["by"]] + comments.map { |c| c["by"] }).compact.uniq
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
        email: "#{username.downcase}@hn.import",
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

  story_user = users[story["by"]] || Discourse.system_user
  story_raw = +""
  story_raw << "[#{story["title"]}](#{story["url"]})\n\n" if story["url"]
  story_raw << story["text"] if story["text"]
  story_raw = story["title"] if story_raw.blank?

  topic_post =
    PostCreator.new(
      story_user,
      title: story["title"],
      raw: story_raw,
      category: category_id,
      created_at: Time.at(story["time"]),
      skip_validations: true,
      import_mode: true,
    ).create!

  # HN exposes score on stories only (not on comments)
  topic_post.update_columns(like_count: story["score"].to_i) if story["score"].to_i > 0

  puts "  Created topic ##{topic_post.topic_id} (score: #{story["score"]})"

  # -- Step 4: Create comments with threading --

  hn_id_to_post = { hn_item_id => topic_post }

  comments.each_with_index do |comment, idx|
    user = users[comment["by"]] || Discourse.system_user
    parent_post = hn_id_to_post[comment["parent"]]

    opts = {
      topic_id: topic_post.topic_id,
      raw: comment["text"],
      created_at: Time.at(comment["time"]),
      skip_validations: true,
      import_mode: true,
      cook_method: Post.cook_methods[:raw_html],
    }

    if parent_post && parent_post.post_number > 1
      opts[:reply_to_post_number] = parent_post.post_number
    end

    post = PostCreator.new(user, opts).create!
    hn_id_to_post[comment["id"]] = post

    print "\r  Posts: #{idx + 1}/#{comments.size}"
  rescue => e
    puts "\n  ERROR on comment #{comment["id"]}: #{e.message}"
  end

  topic = topic_post.topic
  topic.update_columns(bumped_at: topic_post.created_at, updated_at: topic_post.created_at)

  topic_url = "#{Discourse.base_url}/t/#{topic.slug}/#{topic.id}"
  puts "\n\nDone! #{hn_id_to_post.size} posts created."
  puts "URL: #{topic_url}"

  topic_url
end
