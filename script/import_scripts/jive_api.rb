require "htmlentities"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::JiveApi < ImportScripts::Base

  COUNT ||= 100
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

    mark_topics_as_solved
  end

  def import_users
    puts "", "importing users..."

    imported_users = 0
    start_index = [0, Math.floor(PostCustomField.where(name: "import_id").count / COUNT.to_f) - COUNT].max

    loop do
      users = get("people/@all?fields=initialLogin,emails,displayName,mentionName,thumbnailUrl,-resources&count=#{COUNT}&startIndex=#{start_index}", true)
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

      break if users["list"].size < COUNT || users["links"].blank? || users["links"]["next"].blank?
      imported_users += users["list"].size
      break unless start_index = users["links"]["next"][/startIndex=(\d+)/, 1]
    end
  end

  def import_discussions
    puts "", "importing discussions & questions..."

    start_index = 0
    fields = "fields=published,tags,contentID,author.id,content.text,subject,viewCount,question,-resources,-author.resources"
    filter = "&filter=creationDate(null,2017-01-01T00:00:00Z)"

    loop do
      discussions = get("contents?#{fields}&filter=status(published)&filter=type(discussion)#{filter}&sort=dateCreatedAsc&count=#{COUNT}&startIndex=#{start_index}")
      discussions["list"].each do |discussion|
        topic = {
          id: discussion["contentID"],
          created_at: discussion["published"],
          title: @htmlentities.decode(discussion["subject"]),
          raw: discussion["content"]["text"],
          user_id: user_id_from_imported_user_id(discussion["author"]["id"]) || Discourse::SYSTEM_USER_ID,
          # category: discussion["question"] ? 26 : 21,
          views: discussion["viewCount"],
          cook_method: Post.cook_methods[:raw_html],
          custom_fields: { import_id: discussion["contentID"] },
          post_create_action: proc do |post|
            tags = discussion["tags"].compact.map(&:strip).select(&:present?)
            DiscourseTagging.tag_topic_by_names(post.topic, STAFF_GUARDIAN, tags) unless tags.empty?
          end
        }

        post_id = post_id_from_imported_post_id(topic[:id])
        parent_post = post_id ? Post.unscoped.find_by(id: post_id) : create_post(topic, topic[:id])

        import_comments(discussion["contentID"], parent_post.topic_id) if parent_post
      end

      break if discussions["list"].size < COUNT || discussions["links"].blank? || discussions["links"]["next"].blank?
      break unless start_index = discussions["links"]["next"][/startIndex=(\d+)/, 1]
    end
  end

  def import_comments(discussion_id, topic_id)
    start_index = 0
    fields = "fields=published,author.id,content.text,parent,answer,-resources,-author.resources"

    loop do
      comments = get("messages/contents/#{discussion_id}?#{fields}&count=#{COUNT}&startIndex=#{start_index}")
      comments["list"].each do |comment|
        next if post_id_from_imported_post_id(comment["id"])

        post = {
          id: comment["id"],
          created_at: comment["published"],
          topic_id: topic_id,
          user_id: user_id_from_imported_user_id(comment["author"]["id"]) || Discourse::SYSTEM_USER_ID,
          raw: comment["content"]["text"],
          cook_method: Post.cook_methods[:raw_html],
          custom_fields: { import_id: comment["id"] },
        }
        post[:custom_fields][:is_accepted_answer] = true if comment["answer"]

        if parent_post_id = comment["parent"][/\/messages\/(\d+)/, 1]
          if parent = topic_lookup_from_imported_post_id(parent_post_id)
            post[:reply_to_post_number] = parent[:post_number]
          end
        end

        create_post(post, post[:id])
      end

      break if comments["list"].size < COUNT || comments["links"].blank? || comments["links"]["next"].blank?
      break unless start_index = comments["links"]["next"][/startIndex=(\d+)/, 1]
    end
  end

  def import_posts
    puts "", "importing blog posts..."

    start_index = 0
    fields = "fields=published,tags,contentID,author.id,content.text,subject,viewCount,permalink,-resources,-author.resources"
    filter = "&filter=creationDate(null,2016-05-01T00:00:00Z)"

    loop do
      posts = get("contents?#{fields}&filter=status(published)&filter=type(post)#{filter}&sort=dateCreatedAsc&count=#{COUNT}&startIndex=#{start_index}")
      posts["list"].each do |post|
        next if post_id_from_imported_post_id(post["contentID"])
        pp = {
          id: post["contentID"],
          created_at: post["published"],
          title: @htmlentities.decode(post["subject"]),
          raw: post["content"]["text"],
          user_id: user_id_from_imported_user_id(post["author"]["id"]) || Discourse::SYSTEM_USER_ID,
          # category: 7,
          views: post["viewCount"],
          cook_method: Post.cook_methods[:raw_html],
          custom_fields: { import_id: post["contentID"], import_permalink: post["permalink"] },
          post_create_action: proc do |p|
            tags = post["tags"].compact.map(&:strip).select(&:present?)
            DiscourseTagging.tag_topic_by_names(p.topic, STAFF_GUARDIAN, tags) unless tags.empty?
          end
        }

        create_post(pp, pp[:id])
      end

      break if posts["list"].size < COUNT || posts["links"].blank? || posts["links"]["next"].blank?
      break unless start_index = posts["links"]["next"][/startIndex=(\d+)/, 1]
    end
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
  rescue => e
    retry if (tries -= 1) >= 0
  end

end

ImportScripts::JiveApi.new.perform
