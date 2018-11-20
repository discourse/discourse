# cf. https://github.com/rails-sqlserver/tiny_tds#install
require "tiny_tds"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::StackOverflow < ImportScripts::Base

  BATCH_SIZE ||= 1000

  def initialize
    super

    @client = TinyTds::Client.new(
      host: ENV["DB_HOST"],
      username: ENV["DB_USERNAME"],
      password: ENV["DB_PASSWORD"],
      database: ENV["DB_NAME"],
    )
  end

  def execute
    SiteSetting.tagging_enabled = true

    # TODO: import_groups
    import_users
    import_posts
    import_likes
    mark_topics_as_solved
  end

  def import_users
    puts "", "Importing users..."

    last_user_id = -1
    total = query("SELECT COUNT(*) count FROM Users WHERE Id > 0").first["count"]

    batches(BATCH_SIZE) do |offset|
      users = query(<<~SQL
        SELECT TOP #{BATCH_SIZE}
               Id
             , UserTypeId
             , CreationDate
             , LastLoginDate
             , LastLoginIP
             , Email
             , DisplayName
             , WebsiteUrl
             , RealName
             , Location
             , Birthday
             , ProfileImageUrl
          FROM Users
         WHERE Id > 0
           AND Id > #{last_user_id}
         ORDER BY Id
      SQL
      ).to_a

      break if users.empty?

      last_user_id = users[-1]["Id"]
      user_ids = users.map { |u| u["Id"] }

      next if all_records_exist?(:users, user_ids)

      create_users(users, total: total, offset: offset) do |u|
        {
          id: u["Id"],
          admin: u["UserTypeId"] == 4,
          created_at: u["CreationDate"],
          last_seen_at: u["LastLoginDate"],
          ip_address: u["LastLoginIP"],
          email: u["Email"],
          username: u["DisplayName"],
          website: u["WebsiteUrl"],
          name: u["RealName"],
          location: u["Location"],
          date_of_birth: u["Birthday"],
          post_create_action: proc do |user|
            if u["ProfileImageUrl"].present?
              UserAvatar.import_url_for_user(u["ProfileImageUrl"], user) rescue nil
            end
          end
        }
      end
    end
  end

  def import_posts
    puts "", "Importing posts..."

    last_post_id = -1
    total = query("SELECT COUNT(*) count FROM Posts WHERE PostTypeId IN (1,2,3)").first["count"] +
      query("SELECT COUNT(*) count FROM PostComments WHERE PostId IN (SELECT Id FROM Posts WHERE PostTypeId IN (1,2,3))").first["count"]

    batches(BATCH_SIZE) do |offset|
      posts = query(<<~SQL
        SELECT TOP #{BATCH_SIZE}
               Id
             , PostTypeId
             , CreationDate
             , Body
             , OwnerUserId AS UserId
             , Title
             , Tags
             , DeletionDate
             , ParentId
             , IsAcceptedAnswer
             , CASE WHEN (ClosedDate IS NOT NULL OR LockedDate IS NOT NULL) THEN 1 ELSE 0 END AS Closed
          FROM Posts
         WHERE PostTypeId IN (1,2,3)
           AND Id > #{last_post_id}
         ORDER BY Id
      SQL
      ).to_a

      break if posts.empty?

      last_post_id = posts[-1]["Id"]
      post_ids = posts.map { |p| p["Id"] }

      comments = query(<<~SQL
        SELECT CONCAT('Comment-', Id) AS Id
             , PostId AS ParentId
             , Text
             , CreationDate
             , UserId
          FROM PostComments
         WHERE PostId IN (#{post_ids.join(",")})
         ORDER BY Id
      SQL
      ).to_a

      posts_and_comments = (posts + comments).sort_by { |p| p["CreationDate"] }
      post_and_comment_ids = posts_and_comments.map { |p| p["Id"] }

      next if all_records_exist?(:posts, post_and_comment_ids)

      create_posts(posts_and_comments, total: total, offset: offset) do |p|
        raw = p["Body"].present? ? HtmlToMarkdown.new(p["Body"]).to_markdown : p["Text"]

        post = {
          id: p["Id"],
          created_at: p["CreationDate"],
          raw: raw,
          user_id: user_id_from_imported_user_id(p["UserId"]) || -1,
        }

        if p["Title"].present?
          post[:wiki] = p["PostTypeId"] = 3
          post[:title] = p["Title"]
          post[:tags] = p["Tags"].split("|")
          post[:deleted_at] = p["DeletionDate"]
          post[:closed] = p["Closed"] == 1
        elsif t = topic_lookup_from_imported_post_id(p["ParentId"])
          post[:custom_fields] = { is_accepted_answer: true } if p["IsAcceptedAnswer"]
          post[:topic_id] = t[:topic_id]
          post[:reply_to_post_number] = t[:post_number]
        else
          puts "", "", "#{p["Id"]} was not imported", "", ""
          next
        end

        post
      end
    end
  end

  LIKE ||= PostActionType.types[:like]

  def import_likes
    puts "", "Importing post likes..."

    last_like_id = -1

    batches(BATCH_SIZE) do |offset|
      likes = query(<<~SQL
        SELECT TOP #{BATCH_SIZE}
               Id
             , PostId
             , UserId
             , CreationDate
          FROM Posts2Votes
         WHERE VoteTypeId = 2
           AND DeletionDate IS NULL
           AND Id > #{last_like_id}
         ORDER BY Id
      SQL
      ).to_a

      break if likes.empty?

      last_like_id = likes[-1]["Id"]

      likes.each do |l|
        next unless user_id = user_id_from_imported_user_id(l["UserId"])
        next unless post_id = post_id_from_imported_post_id(l["PostId"])
        next unless user = User.find_by(id: user_id)
        next unless post = Post.find_by(id: post_id)
        PostAction.act(user, post, LIKE) rescue nil
      end
    end

    puts "", "Importing comment likes..."

    last_like_id = -1
    total = query("SELECT COUNT(*) count FROM Comments2Votes WHERE VoteTypeId = 2 AND DeletionDate IS NULL").first["count"]

    batches(BATCH_SIZE) do |offset|
      likes = query(<<~SQL
        SELECT TOP #{BATCH_SIZE}
               Id
             , CONCAT('Comment-', PostCommentId) AS PostCommentId
             , UserId
             , CreationDate
          FROM Comments2Votes
         WHERE VoteTypeId = 2
           AND DeletionDate IS NULL
           AND Id > #{last_like_id}
         ORDER BY Id
      SQL
      ).to_a

      break if likes.empty?

      last_like_id = likes[-1]["Id"]

      likes.each do |l|
        next unless user_id = user_id_from_imported_user_id(l["UserId"])
        next unless post_id = post_id_from_imported_post_id(l["PostCommentId"])
        next unless user = User.find_by(id: user_id)
        next unless post = Post.find_by(id: post_id)
        PostAction.act(user, post, LIKE) rescue nil
      end
    end
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

  def query(sql)
    @client.execute(sql)
  end

end

ImportScripts::StackOverflow.new.perform
