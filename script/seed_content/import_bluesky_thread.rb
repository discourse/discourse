# frozen_string_literal: true

# Bluesky Thread Importer for Discourse Rails Console
# Paste this entire script into `rails c` to define the import method.
#
# Usage:
#   import_bluesky("https://bsky.app/profile/carbonbrief.org/post/3mh6aoxqgfk2l")
#   import_bluesky("https://bsky.app/profile/carbonbrief.org/post/3mh6aoxqgfk2l", category_id: 5)
#
#   # Batch import:
#   urls = %w[
#     https://bsky.app/profile/someone.bsky.social/post/abc123
#     https://bsky.app/profile/other.org/post/def456
#   ]
#   urls.each { |url| import_bluesky(url, category_id: 3) }

require "net/http"
require "json"

def import_bluesky(url, category_id: SiteSetting.uncategorized_category_id)
  # -- Step 1: Parse URL and resolve handle to DID --

  match = url.match(%r{bsky\.app/profile/([^/]+)/post/([a-z0-9]+)})
  raise "Invalid Bluesky URL: #{url}" unless match

  handle = match[1]
  rkey = match[2]

  puts "  Resolving handle: #{handle}"

  resolve_uri =
    URI("https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle?handle=#{handle}")
  resolve_resp = Net::HTTP.get_response(resolve_uri)
  unless resolve_resp.is_a?(Net::HTTPSuccess)
    raise "Failed to resolve handle #{handle}: HTTP #{resolve_resp.code}"
  end

  did = JSON.parse(resolve_resp.body)["did"]
  at_uri = "at://#{did}/app.bsky.feed.post/#{rkey}"

  # -- Step 2: Fetch the thread --

  thread_uri =
    URI(
      "https://public.api.bsky.app/xrpc/app.bsky.feed.getPostThread?uri=#{CGI.escape(at_uri)}&depth=1000&parentHeight=0",
    )
  thread_resp = Net::HTTP.get_response(thread_uri)
  unless thread_resp.is_a?(Net::HTTPSuccess)
    raise "Failed to fetch thread: HTTP #{thread_resp.code}"
  end

  thread_data = JSON.parse(thread_resp.body)["thread"]

  root_post = thread_data["post"]

  # Flatten the recursive reply tree via BFS so parents are always created before children
  comments = []
  queue = (thread_data["replies"] || []).dup

  while queue.any?
    node = queue.shift
    next if node["$type"] == "app.bsky.feed.defs#blockedPost"
    next if node["$type"] == "app.bsky.feed.defs#notFoundPost"
    next unless node["post"]

    post = node["post"]
    record = post["record"] || {}
    next if record["text"].blank?

    parent_uri = record.dig("reply", "parent", "uri") || at_uri
    comments << { post: post, record: record, parent_uri: parent_uri }

    queue.concat(node["replies"]) if node["replies"]
  end

  puts "  Post:     #{root_post.dig("record", "text").to_s.truncate(80)}"
  puts "  Replies:  #{comments.size}"
  puts "  Users:    #{comments.map { |c| c[:post].dig("author", "handle") }.uniq.size + 1}"

  # -- Step 3: Create staged users --

  all_authors = [root_post["author"]] + comments.map { |c| c[:post]["author"] }
  all_authors.uniq! { |a| a["did"] }

  users = {}

  all_authors.each do |author|
    bsky_handle = author["handle"]
    # Bluesky handles can contain dots; Discourse usernames cannot
    username = bsky_handle.sub(/\.bsky\.social$/, "").tr(".", "_").truncate(20, omission: "")
    username = username.gsub(/[^a-zA-Z0-9_]/, "_") if username !~ /\A[a-zA-Z0-9_]+\z/

    existing = User.find_by(username: username)
    if existing
      users[author["did"]] = existing
      next
    end

    user =
      User.new(
        username: username,
        name: author["displayName"].presence,
        email: "#{username.downcase}@bluesky.import",
        password: SecureRandom.hex(20),
        staged: true,
        active: true,
      )
    user.skip_email_validation = true
    user.save!(validate: false)

    if author["avatar"].present?
      UserAvatar.import_url_for_user(author["avatar"], user, skip_rate_limit: true)
    end

    users[author["did"]] = user
  end

  puts "  Staged users ready."

  # -- Step 4: Create the topic --

  root_record = root_post["record"] || {}
  root_author_did = root_post.dig("author", "did")
  story_user = users[root_author_did] || Discourse.system_user

  story_raw = bluesky_record_to_markdown(root_record, root_post)
  story_raw = root_record["text"] if story_raw.blank?

  # Use first line or truncated text as title
  title = root_record["text"].to_s.lines.first.to_s.strip.truncate(250)

  topic_post =
    PostCreator.new(
      story_user,
      title: title,
      raw: story_raw,
      category: category_id,
      created_at: Time.parse(root_record["createdAt"]),
      skip_validations: true,
      import_mode: true,
    ).create!

  if root_post["likeCount"].to_i > 0
    topic_post.update_columns(like_count: root_post["likeCount"].to_i)
  end

  puts "  Created topic ##{topic_post.topic_id} (likes: #{root_post["likeCount"]})"

  # -- Step 5: Create replies with threading --

  uri_to_post = { at_uri => topic_post }

  comments.each_with_index do |comment, idx|
    post_data = comment[:post]
    record = comment[:record]
    author_did = post_data.dig("author", "did")
    user = users[author_did] || Discourse.system_user

    parent_post = uri_to_post[comment[:parent_uri]]

    raw = bluesky_record_to_markdown(record, post_data)

    opts = {
      topic_id: topic_post.topic_id,
      raw: raw,
      created_at: Time.parse(record["createdAt"]),
      skip_validations: true,
      import_mode: true,
    }

    if parent_post && parent_post.post_number > 1
      opts[:reply_to_post_number] = parent_post.post_number
    end

    post = PostCreator.new(user, opts).create!
    uri_to_post[post_data["uri"]] = post

    post.update_columns(like_count: post_data["likeCount"].to_i) if post_data["likeCount"].to_i > 0

    print "\r  Posts: #{idx + 1}/#{comments.size}"
  rescue => e
    puts "\n  ERROR on reply #{post_data["uri"]}: #{e.message}"
  end

  topic = topic_post.topic
  topic.update_columns(bumped_at: topic_post.created_at, updated_at: topic_post.created_at)

  topic_url = "#{Discourse.base_url}/t/#{topic.slug}/#{topic.id}"
  puts "\n\nDone! #{uri_to_post.size} posts created."
  puts "URL: #{topic_url}"

  topic_url
end

# Convert a Bluesky post record to Markdown, applying facets (links, mentions)
# and appending any embedded content (images, external links, quotes).
def bluesky_record_to_markdown(record, post_data = nil)
  text = record["text"].to_s
  facets = record["facets"] || []

  if facets.any?
    # Facets use byte offsets; convert to byte-aware slicing
    bytes = text.dup.force_encoding("UTF-8").bytes.to_a
    # Sort facets by start position descending so replacements don't shift offsets
    sorted = facets.sort_by { |f| -(f.dig("index", "byteStart") || 0) }

    sorted.each do |facet|
      byte_start = facet.dig("index", "byteStart")
      byte_end = facet.dig("index", "byteEnd")
      next unless byte_start && byte_end

      original = bytes[byte_start...byte_end].pack("C*").force_encoding("UTF-8")
      feature = (facet["features"] || []).first
      next unless feature

      replacement =
        case feature["$type"]
        when "app.bsky.richtext.facet#link"
          "[#{original}](#{feature["uri"]})"
        when "app.bsky.richtext.facet#mention"
          "[#{original}](https://bsky.app/profile/#{feature["did"]})"
        when "app.bsky.richtext.facet#tag"
          "[##{feature["tag"]}](https://bsky.app/hashtag/#{feature["tag"]})"
        else
          original
        end

      replacement_bytes = replacement.encode("UTF-8").bytes.to_a
      bytes[byte_start...byte_end] = replacement_bytes
    end

    text = bytes.pack("C*").force_encoding("UTF-8")
  end

  # Append embedded content
  embed = post_data&.dig("embed") || record["embed"]
  if embed
    case embed["$type"]
    when "app.bsky.embed.images#view"
      (embed["images"] || []).each do |img|
        alt = img["alt"].presence || "image"
        text += "\n\n![#{alt}](#{img["fullsize"]})"
      end
    when "app.bsky.embed.external#view"
      ext = embed["external"]
      text += "\n\n[#{ext["title"].presence || ext["uri"]}](#{ext["uri"]})" if ext
    when "app.bsky.embed.record#view"
      quoted = embed.dig("record")
      if quoted && quoted["value"]
        quote_author = quoted.dig("author", "handle") || "unknown"
        quote_text = quoted.dig("value", "text").to_s.truncate(300)
        text += "\n\n[quote]\n#{quote_author}: #{quote_text}\n[/quote]"
      end
    when "app.bsky.embed.recordWithMedia#view"
      # Post with both quoted record and media
      media = embed.dig("media")
      if media && media["$type"] == "app.bsky.embed.images#view"
        (media["images"] || []).each do |img|
          alt = img["alt"].presence || "image"
          text += "\n\n![#{alt}](#{img["fullsize"]})"
        end
      end
      quoted = embed.dig("record", "record")
      if quoted && quoted["value"]
        quote_author = quoted.dig("author", "handle") || "unknown"
        quote_text = quoted.dig("value", "text").to_s.truncate(300)
        text += "\n\n[quote]\n#{quote_author}: #{quote_text}\n[/quote]"
      end
    end
  end

  text
end
