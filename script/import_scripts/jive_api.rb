require "nokogiri"
require "htmlentities"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::JiveApi < ImportScripts::Base

  USER_COUNT ||= 1000
  POST_COUNT ||= 100
  STAFF_GUARDIAN ||= Guardian.new(Discourse.system_user)

  def initialize
    super
    @base_uri = ENV["BASE_URI"]
    @username = ENV["USERNAME"]
    @password = ENV["PASSWORD"]
    @htmlentities = HTMLEntities.new
  end

  def execute
    import_users
    import_discussions
    import_posts
    import_bookmarks

    mark_topics_as_solved
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

      break if users["list"].size < USER_COUNT || users["links"].blank? || users["links"]["next"].blank?
      imported_users += users["list"].size
      break unless start_index = users["links"]["next"][/startIndex=(\d+)/, 1]
    end
  end

  def import_discussions
    puts "", "importing discussions & questions..."

    start_index = 0
    fields = "fields=published,contentID,author.id,content.text,subject,viewCount,likeCount,question,-resources,-author.resources"
    filter = "&filter=creationDate(null,2017-01-01T00:00:00Z)"

    loop do
      discussions = get("contents?#{fields}&filter=status(published)&filter=type(discussion)#{filter}&sort=dateCreatedAsc&count=#{POST_COUNT}&startIndex=#{start_index}")
      discussions["list"].each do |discussion|
        topic = {
          id: discussion["contentID"],
          created_at: discussion["published"],
          title: @htmlentities.decode(discussion["subject"]),
          raw: process_raw(discussion["content"]["text"]),
          user_id: user_id_from_imported_user_id(discussion["author"]["id"]) || Discourse::SYSTEM_USER_ID,
          category: discussion["question"] ? 5 : 21,
          views: discussion["viewCount"],
          custom_fields: { import_id: discussion["contentID"] },
        }

        post_id = post_id_from_imported_post_id(topic[:id])
        parent_post = post_id ? Post.unscoped.find_by(id: post_id) : create_post(topic, topic[:id])

        if parent_post&.id && parent_post&.topic_id
          import_likes(discussion["contentID"], parent_post.id, parent_post.topic_id) if discussion["likeCount"].to_i > 0
          import_comments(discussion["contentID"], parent_post.topic_id)
        end
      end

      break if discussions["list"].size < POST_COUNT || discussions["links"].blank? || discussions["links"]["next"].blank?
      break unless start_index = discussions["links"]["next"][/startIndex=(\d+)/, 1]
    end
  end

  def import_likes(discussion_id, post_id, topic_id)
    start_index = 0
    fields = "fields=id"

    loop do
      likes = get("contents/#{discussion_id}/likes?&count=#{USER_COUNT}&startIndex=#{start_index}", true)
      likes["list"].each do |like|
        next unless user_id = user_id_from_imported_user_id(like["id"])
        next if PostAction.exists?(user_id: user_id, post_id: post_id, post_action_type_id: PostActionType.types[:like])
        PostAction.act(User.find(user_id), Post.find(post_id), PostActionType.types[:like])
      end

      break if likes["list"].size < USER_COUNT || likes["links"].blank? || likes["links"]["next"].blank?
      break unless start_index = likes["links"]["next"][/startIndex=(\d+)/, 1]
    end
  end

  def import_comments(discussion_id, topic_id)
    start_index = 0
    fields = "fields=published,author.id,content.text,parent,answer,likeCount,-resources,-author.resources"

    loop do
      comments = get("messages/contents/#{discussion_id}?#{fields}&hierarchical=false&count=#{POST_COUNT}&startIndex=#{start_index}")
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
        post[:custom_fields][:is_accepted_answer] = true if comment["answer"]

        if parent_post_id = comment["parent"][/\/messages\/(\d+)/, 1]
          if parent = topic_lookup_from_imported_post_id(parent_post_id)
            post[:reply_to_post_number] = parent[:post_number]
          end
        end

        if created_post = create_post(post, post[:id])
          import_likes(discussion_id, created_post.id, topic_id) if comment["likeCount"].to_i > 0
        end
      end

      break if comments["list"].size < POST_COUNT || comments["links"].blank? || comments["links"]["next"].blank?
      break unless start_index = comments["links"]["next"][/startIndex=(\d+)/, 1]
    end
  end

  def import_posts
    puts "", "importing blog posts..."

    start_index = 0
    fields = "fields=published,contentID,author.id,content.text,subject,viewCount,permalink,-resources,-author.resources"
    filter = "&filter=creationDate(null,2016-05-01T00:00:00Z)"

    loop do
      posts = get("contents?#{fields}&filter=status(published)&filter=type(post)#{filter}&sort=dateCreatedAsc&count=#{POST_COUNT}&startIndex=#{start_index}")
      posts["list"].each do |post|
        next if post_id_from_imported_post_id(post["contentID"])
        pp = {
          id: post["contentID"],
          created_at: post["published"],
          title: @htmlentities.decode(post["subject"]),
          raw: process_raw(post["content"]["text"]),
          user_id: user_id_from_imported_user_id(post["author"]["id"]) || Discourse::SYSTEM_USER_ID,
          category: 7,
          views: post["viewCount"],
          custom_fields: { import_id: post["contentID"], import_permalink: post["permalink"] },
        }

        if created_post = create_post(pp, pp[:id])
          import_likes(pp[:id], created_post.id, created_post.topic_id)
        end
      end

      break if posts["list"].size < POST_COUNT || posts["links"].blank? || posts["links"]["next"].blank?
      break unless start_index = posts["links"]["next"][/startIndex=(\d+)/, 1]
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
    filter = "&filter=creationDate(null,2017-01-01T00:00:00Z)"

    loop do
      favorites = get("contents?#{fields}&filter=type(favorite)#{filter}&sort=dateCreatedAsc&count=#{POST_COUNT}&startIndex=#{start_index}")
      favorites["list"].each do |favorite|
        next unless user_id = user_id_from_imported_user_id(favorite["author"]["id"])
        next unless post_id = post_id_from_imported_post_id(favorite["favoriteObject"]["id"])
        next if PostAction.exists?(user_id: user_id, post_id: post_id, post_action_type_id: PostActionType.types[:bookmark])
        PostAction.act(User.find(user_id), Post.find(post_id), PostActionType.types[:bookmark])
      end

      break if favorites["list"].size < POST_COUNT || favorites["links"].blank? || favorites["links"]["next"].blank?
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

    PostAction.exec_sql <<-SQL
      INSERT INTO topic_custom_fields (name, value, topic_id, created_at, updated_at)
      SELECT 'accepted_answer_post_id', pcf.post_id, p.topic_id, p.created_at, p.created_at
        FROM post_custom_fields pcf
        JOIN posts p ON p.id = pcf.post_id
       WHERE pcf.name = 'is_accepted_answer'
    SQL
  end

  def get(query, authenticated=false)
    tries ||= 3

    command = ["curl", "--silent"]
    command << "--user \"#{@username}:#{@password}\"" if authenticated
    command << "\"#{@base_uri}/api/core/v3/#{query}\""

    puts command.join(" ")

    JSON.parse `#{command.join(" ")}`
  rescue
    retry if (tries -= 1) >= 0
  end

end

ImportScripts::JiveApi.new.perform
