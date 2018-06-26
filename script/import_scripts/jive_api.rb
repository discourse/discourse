require "nokogiri"
require "htmlentities"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# https://developers.jivesoftware.com/api/v3/cloud/rest/index.html

class ImportScripts::JiveApi < ImportScripts::Base

  USER_COUNT ||= 1000
  POST_COUNT ||= 100
  STAFF_GUARDIAN ||= Guardian.new(Discourse.system_user)

  TO_IMPORT ||= [
    #############################
    # WHOLE CATEGORY OF CONTENT #
    #############################

    # Announcement & News
    { jive_object: { type: 37, id: 1004 }, filters: { created_after: 1.year.ago, type: "post" }, category_id: 7 },
    # Questions & Answers / General Discussions
    { jive_object: { type: 14, id: 2006 }, filters: { created_after: 6.months.ago, type: "discussion" }, category: Proc.new { |c| c["question"] ? 5 : 21 } },
    # Anywhere beta
    { jive_object: { type: 14, id: 2052 }, filters: { created_after: 6.months.ago, type: "discussion" }, category_id: 22 },
    # Tips & Tricks
    { jive_object: { type: 37, id: 1284 }, filters: { type: "post" }, category_id: 6 },
    { jive_object: { type: 37, id: 1319 }, filters: { type: "post" }, category_id: 6 },
    { jive_object: { type: 37, id: 1177 }, filters: { type: "post" }, category_id: 6 },
    { jive_object: { type: 37, id: 1165 }, filters: { type: "post" }, category_id: 6 },
    # Ambassadors
    { jive_object: { type: 700, id: 1001 }, filters: { type: "discussion" }, authenticated: true, category_id: 8 },
    # Experts
    { jive_object: { type: 700, id: 1034 }, filters: { type: "discussion" }, authenticated: true, category_id: 15 },
    # Feature Requests
    { jive_object: { type: 14, id: 2015 }, filters: { type: "idea" }, category_id: 31 },

    ####################
    # SELECTED CONTENT #
    ####################

    # Announcement & News
    { jive_object: { type: 37, id: 1004 }, filters: { entities: { 38 => [1345, 1381, 1845, 2046, 2060, 2061] } }, category_id: 7 },
    # Problem Solving
    { jive_object: { type: 14, id: 2006 }, filters: { entities: { 2 => [116685, 160745, 177010, 223482, 225036, 233228, 257882, 285103, 292297, 345243, 363250, 434546] } }, category_id: 10 },
    # General Discussions
    { jive_object: { type: 14, id: 2006 }, filters: { entities: { 2 => [178203, 188350, 312734] } }, category_id: 21 },
    # Questions & Answers
    { jive_object: { type: 14, id: 2006 }, filters: { entities: { 2 => [418811] } }, category_id: 5 },
  ]

  def initialize
    super
    @base_uri = ENV["BASE_URI"]
    @username = ENV["USERNAME"]
    @password = ENV["PASSWORD"]
    @htmlentities = HTMLEntities.new
  end

  def execute
    update_existing_users
    import_users
    import_contents
    import_bookmarks
    mark_topics_as_solved
  end

  def update_existing_users
    puts "", "updating existing users..."

    # we just need to do this once
    return if User.human_users.limit(101).count > 100

    User.human_users.find_each do |user|
      people = get("people/email/#{user.email}?fields=initialLogin,-resources", true)
      if people && people["initialLogin"].present?
        created_at = DateTime.parse(people["initialLogin"])
        if user.created_at > created_at
          user.update_columns(created_at: created_at)
        end
      end
    end
  end

  def import_users
    puts "", "importing users..."

    imported_users = 0
    start_index = [0, UserCustomField.where(name: "import_id").count - USER_COUNT].max

    loop do
      users = get("people/@all?fields=initialLogin,emails,displayName,mentionName,thumbnailUrl,-resources&count=#{USER_COUNT}&startIndex=#{start_index}", true)
      create_users(users["list"], offset: imported_users) do |user|
        {
          id: user["id"],
          created_at: user["initialLogin"],
          email: user["emails"].find { |email| email["primary"] }["value"],
          username: user["mentionName"],
          name: user["displayName"],
          avatar_url: user["thumbnailUrl"],
        }
      end

      break if users["list"].size < USER_COUNT || users.dig("links", "next").blank?
      imported_users += users["list"].size
      break unless start_index = users["links"]["next"][/startIndex=(\d+)/, 1]
    end
  end

  def import_contents
    puts "", "importing contents..."

    TO_IMPORT.each do |to_import|
      puts Time.now
      entity = to_import[:jive_object]
      places = get("places?fields=placeID,name,-resources&filter=entityDescriptor(#{entity[:type]},#{entity[:id]})", to_import[:authenticated])
      import_place_contents(places["list"][0], to_import) if places && places["list"].present?
    end
  end

  def import_place_contents(place, to_import)
    puts "", "importing contents for '#{place["name"]}'..."

    start_index = 0

    if to_import.dig(:filters, :entities).present?
      path = "contents"
      entities = to_import[:filters][:entities].flat_map { |type, ids| ids.map { |id| "#{type},#{id}" } }
      filters = "filter=entityDescriptor(#{entities.join(",")})"
    else
      path = "places/#{place["placeID"]}/contents"
      filters = "filter=status(published)"
      if to_import[:filters]
        filters << "&filter=type(#{to_import[:filters][:type]})" if to_import[:filters][:type].present?
        filters << "&filter=creationDate(null,#{to_import[:filters][:created_after].strftime("%Y-%m-%dT%TZ")})" if to_import[:filters][:created_after].present?
      end
    end

    loop do
      contents = get("#{path}?#{filters}&sort=dateCreatedAsc&count=#{POST_COUNT}&startIndex=#{start_index}", to_import[:authenticated])
      contents["list"].each do |content|
        content_id = content["contentID"].presence || "#{content["type"]}_#{content["id"]}"

        custom_fields = { import_id: content_id }
        custom_fields[:import_permalink] = content["permalink"] if content["permalink"].present?

        topic = {
          id: content_id,
          created_at: content["published"],
          title: @htmlentities.decode(content["subject"]),
          raw: process_raw(content["content"]["text"]),
          user_id: user_id_from_imported_user_id(content["author"]["id"]) || Discourse::SYSTEM_USER_ID,
          views: content["viewCount"],
          custom_fields: custom_fields,
        }

        if to_import[:category]
          topic[:category] = to_import[:category].call(content)
        else
          topic[:category] = to_import[:category_id]
        end

        post_id = post_id_from_imported_post_id(topic[:id])
        parent_post = post_id ? Post.unscoped.find_by(id: post_id) : create_post(topic, topic[:id])

        if parent_post&.id && parent_post&.topic_id
          resources = content["resources"]
          import_likes(resources["likes"]["ref"], parent_post.id) if content["likeCount"].to_i > 0 && resources.dig("likes", "ref").present?
          if content["replyCount"].to_i > 0
            import_comments(resources["comments"]["ref"], parent_post.topic_id, to_import) if resources.dig("comments", "ref").present?
            import_messages(resources["messages"]["ref"], parent_post.topic_id, to_import) if resources.dig("messages", "ref").present?
          end
        end
      end

      break if contents["list"].size < POST_COUNT || contents.dig("links", "next").blank?
      break unless start_index = contents["links"]["next"][/startIndex=(\d+)/, 1]
    end
  end

  def import_likes(url, post_id)
    start_index = 0

    loop do
      likes = get("#{url}?&count=#{USER_COUNT}&startIndex=#{start_index}", true)
      break if likes["error"]
      likes["list"].each do |like|
        next unless user_id = user_id_from_imported_user_id(like["id"])
        next if PostAction.exists?(user_id: user_id, post_id: post_id, post_action_type_id: PostActionType.types[:like])
        PostAction.act(User.find(user_id), Post.find(post_id), PostActionType.types[:like])
      end

      break if likes["list"].size < USER_COUNT || likes.dig("links", "next").blank?
      break unless start_index = likes["links"]["next"][/startIndex=(\d+)/, 1]
    end
  end

  def import_comments(url, topic_id, to_import)
    start_index = 0

    loop do
      comments = get("#{url}?hierarchical=false&count=#{POST_COUNT}&startIndex=#{start_index}", to_import[:authenticated])
      break if comments["error"]
      comments["list"].each do |comment|
        next if post_id_from_imported_post_id(comment["id"])

        post = {
          id: comment["id"],
          created_at: comment["published"],
          topic_id: topic_id,
          user_id: user_id_from_imported_user_id(comment["author"]["id"]) || Discourse::SYSTEM_USER_ID,
          raw: process_raw(comment["content"]["text"]),
          custom_fields: { import_id: comment["id"] },
        }

        if (parent_post_id = comment["parentID"]).to_i > 0
          if parent = topic_lookup_from_imported_post_id(parent_post_id)
            post[:reply_to_post_number] = parent[:post_number]
          end
        end

        if created_post = create_post(post, post[:id])
          if comment["likeCount"].to_i > 0 && comment.dig("resources", "likes", "ref").present?
            import_likes(comment["resources"]["likes"]["ref"], created_post.id)
          end
        end
      end

      break if comments["list"].size < POST_COUNT || comments.dig("links", "next").blank?
      break unless start_index = comments["links"]["next"][/startIndex=(\d+)/, 1]
    end
  end

  def import_messages(url, topic_id, to_import)
    start_index = 0

    loop do
      messages = get("#{url}?hierarchical=false&count=#{POST_COUNT}&startIndex=#{start_index}", to_import[:authenticated])
      break if messages["error"]
      messages["list"].each do |message|
        next if post_id_from_imported_post_id(message["id"])

        post = {
          id: message["id"],
          created_at: message["published"],
          topic_id: topic_id,
          user_id: user_id_from_imported_user_id(message["author"]["id"]) || Discourse::SYSTEM_USER_ID,
          raw: process_raw(message["content"]["text"]),
          custom_fields: { import_id: message["id"] },
        }
        post[:custom_fields][:is_accepted_answer] = true if message["answer"]

        if (parent_post_id = message["parentID"].to_i) > 0
          if parent = topic_lookup_from_imported_post_id(parent_post_id)
            post[:reply_to_post_number] = parent[:post_number]
          end
        end

        if created_post = create_post(post, post[:id])
          if message["likeCount"].to_i > 0 && message.dig("resources", "likes", "ref").present?
            import_likes(message["resources"]["likes"]["ref"], created_post.id)
          end
        end
      end

      break if messages["list"].size < POST_COUNT || messages.dig("links", "next").blank?
      break unless start_index = messages["links"]["next"][/startIndex=(\d+)/, 1]
    end
  end

  def create_post(options, import_id)
    post = super(options, import_id)
    if Post === post
      add_post(import_id, post)
      add_topic(post)
    end
    post
  end

  def import_bookmarks
    puts "", "importing bookmarks..."

    start_index = 0
    fields = "fields=author.id,favoriteObject.id,-resources,-author.resources,-favoriteObject.resources"
    filter = "&filter=creationDate(null,2016-01-01T00:00:00Z)"

    loop do
      favorites = get("contents?#{fields}&filter=type(favorite)#{filter}&sort=dateCreatedAsc&count=#{POST_COUNT}&startIndex=#{start_index}")
      favorites["list"].each do |favorite|
        next unless user_id = user_id_from_imported_user_id(favorite["author"]["id"])
        next unless post_id = post_id_from_imported_post_id(favorite["favoriteObject"]["id"])
        next if PostAction.exists?(user_id: user_id, post_id: post_id, post_action_type_id: PostActionType.types[:bookmark])
        PostAction.act(User.find(user_id), Post.find(post_id), PostActionType.types[:bookmark])
      end

      break if favorites["list"].size < POST_COUNT || favorites.dig("links", "next").blank?
      break unless start_index = favorites["links"]["next"][/startIndex=(\d+)/, 1]
    end
  end

  def process_raw(raw)
    doc = Nokogiri::HTML.fragment(raw)

    # convert emoticon
    doc.css("span.emoticon-inline").each do |span|
      name = span["class"][/emoticon_(\w+)/, 1]&.downcase
      name && Emoji.exists?(name) ? span.replace(":#{name}:") : span.remove
    end

    # convert mentions
    doc.css("a.jive-link-profile-small").each { |a| a.replace("@#{a.content}") }

    # fix links
    doc.css("a[href]").each do |a|
      if a["href"]["#{@base_uri}/docs/DOC-"]
        a["href"] = a["href"][/#{Regexp.escape(@base_uri)}\/docs\/DOC-\d+/]
      elsif a["href"][@base_uri]
        a.replace(a.inner_html)
      end
    end

    html = doc.at(".jive-rendered-content").to_html

    HtmlToMarkdown.new(html, keep_img_tags: true).to_markdown
  end

  def mark_topics_as_solved
    puts "", "Marking topics as solved..."

    DB.exec <<~SQL
      INSERT INTO topic_custom_fields (name, value, topic_id, created_at, updated_at)
      SELECT 'accepted_answer_post_id', pcf.post_id, p.topic_id, p.created_at, p.created_at
        FROM post_custom_fields pcf
        JOIN posts p ON p.id = pcf.post_id
       WHERE pcf.name = 'is_accepted_answer'
    SQL
  end

  def get(url_or_path, authenticated = false)
    tries ||= 3

    command = ["curl", "--silent"]
    command << "--user \"#{@username}:#{@password}\"" if !!authenticated
    command << (url_or_path.start_with?("http") ? "\"#{url_or_path}\"" : "\"#{@base_uri}/api/core/v3/#{url_or_path}\"")

    puts command.join(" ") if ENV["VERBOSE"] == "1"

    JSON.parse `#{command.join(" ")}`
  rescue
    retry if (tries -= 1) >= 0
  end

end

ImportScripts::JiveApi.new.perform
