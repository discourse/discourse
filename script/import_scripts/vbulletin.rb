require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'mysql2'

class ImportScripts::VBulletin < ImportScripts::Base

  DATABASE = "iref"
  BATCH_SIZE = 1000

  def initialize
    super

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      database: DATABASE
    )
  end

  def execute
    import_groups
    import_users
    import_categories
    import_topics
    import_posts

    close_topics
  end

  def import_groups
    puts "", "importing groups..."

    groups = mysql_query <<-SQL
        SELECT usergroupid, title
          FROM usergroup
      ORDER BY usergroupid
    SQL

    create_groups(groups) do |group|
      {
        id: group["usergroupid"].to_i,
        name: group["title"]
      }
    end
  end

  def import_users
    puts "", "importing users"

    @old_username_to_new_usernames = {}

    user_count = mysql_query("SELECT COUNT(userid) count FROM user").first["count"]

    batches(BATCH_SIZE) do |offset|
      users = mysql_query <<-SQL
          SELECT userid, username, homepage, usertitle, usergroupid, joindate
            FROM user
        ORDER BY userid
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if users.size < 1

      create_users(users, total: user_count, offset: offset) do |user|
        {
          id: user["userid"].to_i,
          username: user["username"],
          email: user["email"].presence || fake_email,
          website: user["homepage"],
          title: user["usertitle"],
          primary_group_id: group_id_from_imported_group_id(user["usergroupid"]),
          created_at: Time.at(user["joindate"].to_i),
          post_create_action: proc do |u|
            @old_username_to_new_usernames[user["username"]] = u.username
          end
        }
      end
    end
  end

  def import_categories
    puts "", "importing top level categories..."

    # TODO: deal with permissions

    top_level_categories = mysql_query <<-SQL
        SELECT forumid, title, description, displayorder
          FROM forum
         WHERE parentid = -1
      ORDER BY forumid
    SQL

    create_categories(top_level_categories) do |category|
      {
        id: category["forumid"].to_i,
        name: category["title"],
        position: category["displayorder"].to_i,
        description: category["description"]
      }
    end

    puts "", "importing children categories..."

    childen_categories = mysql_query <<-SQL
        SELECT forumid, title, description, displayorder, parentid
          FROM forum
         WHERE parentid <> -1
      ORDER BY forumid
    SQL

    create_categories(childen_categories) do |category|
      {
        id: category["forumid"].to_i,
        name: category["title"],
        position: category["displayorder"].to_i,
        description: category["description"].strip!,
        parent_category_id: category_from_imported_category_id(category["parentid"].to_i).try(:[], "id")
      }
    end
  end

  def import_topics
    puts "", "importing topics..."

    # keep track of closed topics
    @closed_topic_ids = []

    topic_count = mysql_query("SELECT COUNT(threadid) count FROM thread").first["count"]

    batches(BATCH_SIZE) do |offset|
      topics = mysql_query <<-SQL
          SELECT t.threadid threadid, t.title title, forumid, open, postuserid, t.dateline dateline, views, t.visible visible, sticky,
                 p.pagetext raw
            FROM thread t
            JOIN post p ON p.postid = t.firstpostid
        ORDER BY t.threadid
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if topics.size < 1

      create_posts(topics, total: topic_count, offset: offset) do |topic|
        topic_id = "thread-#{topic["threadid"]}"
        @closed_topic_ids << topic_id if topic["open"] == "0"
        t = {
          id: topic_id,
          user_id: user_id_from_imported_user_id(topic["postuserid"].to_i) || Discourse::SYSTEM_USER_ID,
          title: CGI.unescapeHTML(topic["title"]).strip[0...255],
          category: category_from_imported_category_id(topic["forumid"].to_i).try(:name),
          raw: preprocess_post_raw(topic["raw"]),
          created_at: Time.at(topic["dateline"].to_i),
          visible: topic["visible"].to_i == 1,
          views: topic["views"].to_i,
        }
        t[:pinned_at] = t[:created_at] if topic["sticky"].to_i == 1
        t
      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    post_count = mysql_query("SELECT COUNT(postid) count FROM post WHERE postid NOT IN (SELECT firstpostid FROM thread)").first["count"]

    batches(BATCH_SIZE) do |offset|
      posts = mysql_query <<-SQL
          SELECT postid, userid, threadid, pagetext raw, dateline, visible, parentid
            FROM post
           WHERE postid NOT IN (SELECT firstpostid FROM thread)
        ORDER BY postid
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if posts.size < 1

      create_posts(posts, total: post_count, offset: offset) do |post|
        next unless topic = topic_lookup_from_imported_post_id("thread-#{post["threadid"]}")
        p = {
          id: post["postid"].to_i,
          user_id: user_id_from_imported_user_id(post["userid"]) || Discourse::SYSTEM_USER_ID,
          topic_id: topic[:topic_id],
          raw: preprocess_post_raw(post["raw"]),
          created_at: Time.at(post["dateline"].to_i),
          hidden: post["visible"].to_i == 0,
        }
        if parent = topic_lookup_from_imported_post_id(post["parentid"])
          p[:reply_to_post_number] = parent[:post_number]
        end
        p
      end
    end
  end

  def close_topics
    puts "", "Closing topics..."

    sql = <<-SQL
      WITH closed_topic_ids AS (
        SELECT t.id AS topic_id
        FROM post_custom_fields pcf
        JOIN posts p ON p.id = pcf.post_id
        JOIN topics t ON t.id = p.topic_id
        WHERE pcf.name = 'import_id'
        AND pcf.value IN (?)
      )
      UPDATE topics
      SET closed = true
      WHERE id IN (SELECT topic_id FROM closed_topic_ids)
    SQL

    Topic.exec_sql(sql, @closed_topic_ids)
  end

  def preprocess_post_raw(raw)
    return "" if raw.blank?

    raw = raw.gsub(/(\\r)?\\n/, "\n")
             .gsub("\\t", "\t")

    # remove attachments
    raw = raw.gsub(/\[attach[^\]]*\]\d+\[\/attach\]/i, "")

    # [HTML]...[/HTML]
    raw = raw.gsub(/\[html\]/i, "\n```html\n")
             .gsub(/\[\/html\]/i, "\n```\n")

    # [PHP]...[/PHP]
    raw = raw.gsub(/\[php\]/i, "\n```php\n")
             .gsub(/\[\/php\]/i, "\n```\n")

    # [HIGHLIGHT="..."]
    raw = raw.gsub(/\[highlight="?(\w+)"?\]/i) { "\n```#{$1.downcase}\n" }

    # [CODE]...[/CODE]
    # [HIGHLIGHT]...[/HIGHLIGHT]
    raw = raw.gsub(/\[\/?code\]/i, "\n```\n")
             .gsub(/\[\/?highlight\]/i, "\n```\n")

    # [SAMP]...[/SAMP]
    raw = raw.gsub(/\[\/?samp\]/i, "`")

    # replace all chevrons with HTML entities
    # NOTE: must be done
    #  - AFTER all the "code" processing
    #  - BEFORE the "quote" processing
    raw = raw.gsub(/`([^`]+)`/im) { "`" + $1.gsub("<", "\u2603") + "`" }
             .gsub("<", "&lt;")
             .gsub("\u2603", "<")

    raw = raw.gsub(/`([^`]+)`/im) { "`" + $1.gsub(">", "\u2603") + "`" }
             .gsub(">", "&gt;")
             .gsub("\u2603", ">")

    # [URL=...]...[/URL]
    raw = raw.gsub(/\[url="?(.+?)"?\](.+)\[\/url\]/i) { "[#{$2}](#{$1})" }

    # [URL]...[/URL]
    # [MP3]...[/MP3]
    raw = raw.gsub(/\[\/?url\]/i, "")
             .gsub(/\[\/?mp3\]/i, "")

    # [MENTION]<username>[/MENTION]
    raw = raw.gsub(/\[mention\](.+?)\[\/mention\]/i) do
      old_username = $1
      if @old_username_to_new_usernames.has_key?(old_username)
        old_username = @old_username_to_new_usernames[old_username]
      end
      "@#{old_username}"
    end

    # [MENTION=<user_id>]<username>[/MENTION]
    # raw = raw.gsub(/\[mention="?(\d+)"?\](.+?)\[\/mention\]/i) do
    #   user_id, old_username = $1, $2
    #   if user = @users.select { |u| u[:userid] == user_id }.first
    #     old_username = @old_username_to_new_usernames[user[:username]] || user[:username]
    #   end
    #   "@#{old_username}"
    # end

    # [QUOTE]...[/QUOTE]
    raw = raw.gsub(/\[quote\](.+?)\[\/quote\]/im) { "\n> #{$1}\n" }

    # [QUOTE=<username>]...[/QUOTE]
    raw = raw.gsub(/\[quote=([^;\]]+)\](.+?)\[\/quote\]/im) do
      old_username, quote = $1, $2
      if @old_username_to_new_usernames.has_key?(old_username)
        old_username = @old_username_to_new_usernames[old_username]
      end
      "\n[quote=\"#{old_username}\"]\n#{quote}\n[/quote]\n"
    end

    # [YOUTUBE]<id>[/YOUTUBE]
    raw = raw.gsub(/\[youtube\](.+?)\[\/youtube\]/i) { "\n//youtu.be/#{$1}\n" }

    # [VIDEO=youtube;<id>]...[/VIDEO]
    raw = raw.gsub(/\[video=youtube;([^\]]+)\].*?\[\/video\]/i) { "\n//youtu.be/#{$1}\n" }

    raw
  end

  def fake_email
    SecureRandom.hex << "@domain.com"
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end

end

ImportScripts::VBulletin.new.perform
