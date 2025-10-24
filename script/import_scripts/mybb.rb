# frozen_string_literal: true

require "mysql2"
require_relative "base"

# Before running this script, paste these lines into your shell,
# then use arrow keys to edit the values
=begin
export DB_HOST="localhost"
export DB_NAME="mybb"
export DB_PW=""
export DB_USER="root"
export TABLE_PREFIX="mybb_"
export UPLOADS_DIR="/data/youruploads"
export BASE="" #
=end

# Call it like this:
#   RAILS_ENV=production ruby script/import_scripts/mybb.rb
class ImportScripts::MyBB < ImportScripts::Base
  DB_HOST = ENV["DB_HOST"] || "localhost"
  DB_NAME = ENV["DB_NAME"] || "mybb"
  DB_PW = ENV["DB_PW"] || ""
  DB_USER = ENV["DB_USER"] || "root"
  TABLE_PREFIX = ENV["TABLE_PREFIX"] || "mybb_"
  UPLOADS_DIR = ENV["UPLOADS"] || "/data/limelightgaming/uploads"
  BATCH_SIZE = 1000
  BASE = ""
  QUIET = true
  IMPORT_DELETED_POSTS = false

  def initialize
    super

    @client =
      Mysql2::Client.new(host: DB_HOST, username: DB_USER, password: DB_PW, database: DB_NAME)
  end

  def execute
    SiteSetting.disable_emails = "non-staff"
    import_users
    import_categories
    import_posts
    import_private_messages
    create_permalinks
    suspend_users
  end

  def import_users
    puts "", "creating users"

    total_count =
      mysql_query(
        "SELECT count(*) count
                                 FROM #{TABLE_PREFIX}users u
                                 JOIN #{TABLE_PREFIX}usergroups g ON g.gid = u.usergroup
                                WHERE g.title != 'Banned';",
      ).first[
        "count"
      ]

    batches(BATCH_SIZE) do |offset|
      results =
        mysql_query(
          "SELECT uid id, email email, username, regdate, g.title `group`, avatar
           FROM #{TABLE_PREFIX}users u
           JOIN #{TABLE_PREFIX}usergroups g ON g.gid = u.usergroup
          WHERE g.title != 'Banned'
          ORDER BY u.uid ASC
          LIMIT #{BATCH_SIZE}
         OFFSET #{offset};",
        )

      break if results.size < 1

      next if all_records_exist? :users, results.map { |u| u["id"].to_i }

      create_users(results, total: total_count, offset: offset) do |user|
        avatar_url = user["avatar"].match(/^http/) ? user["avatar"].gsub(/\?.*/, "") : nil
        {
          id: user["id"],
          email: user["email"],
          username: user["username"],
          created_at: Time.zone.at(user["regdate"]),
          moderator: user["group"] == "Super Moderators",
          admin: user["group"] == "Administrators",
          avatar_url: avatar_url,
          post_create_action:
            proc do |newuser|
              if user["avatar"].present?
                avatar = user["avatar"].gsub(/\?.*/, "")
                if avatar.match(/^http.*/)
                  UserAvatar.import_url_for_user(avatar, newuser)
                else
                  filename = File.join(UPLOADS_DIR, avatar)
                  @uploader.create_avatar(newuser, filename) if File.exist?(filename)
                end
              end
            end,
        }
      end
    end
  end

  def import_categories
    results =
      mysql_query(
        "
      SELECT fid id, pid parent_id, left(name, 50) name, description
        FROM #{TABLE_PREFIX}forums
    ORDER BY pid ASC, fid ASC
    ",
      )

    create_categories(results) do |row|
      h = {
        id: row["id"],
        name: CGI.unescapeHTML(row["name"]),
        description: CGI.unescapeHTML(row["description"]),
      }
      if row["parent_id"].to_i > 0
        h[:parent_category_id] = category_id_from_imported_category_id(row["parent_id"])
      end
      h
    end
  end

  def import_posts
    puts "", "creating topics and posts"

    total_count = mysql_query("SELECT count(*) count from #{TABLE_PREFIX}posts").first["count"]

    batches(BATCH_SIZE) do |offset|
      results =
        mysql_query(
          "
        SELECT p.pid id,
               p.tid topic_id,
               t.fid category_id,
               t.subject title,
               t.firstpost first_post_id,
               p.uid user_id,
               p.message raw,
               p.dateline post_time
          FROM #{TABLE_PREFIX}posts p,
               #{TABLE_PREFIX}threads t
         WHERE p.tid = t.tid
        #{"AND (p.visible = 1 AND t.visible = 1)" unless IMPORT_DELETED_POSTS}
      ORDER BY p.dateline
         LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
      ",
        )

      break if results.size < 1

      next if all_records_exist? :posts, results.map { |m| m["id"].to_i }

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        # If you have imported a phpbb forum to mybb previously there might
        # be a problem with #{TABLE_PREFIX}threads.firstpost. If these ids are wrong
        # the thread cannot be imported to discourse as the topic post is
        # missing. This query retrieves the first_post_id manually. As it
        # will decrease the performance it is commented out by default.
        # m['first_post_id'] = mysql_query("
        #   SELECT   p.pid id,
        #   FROM     #{TABLE_PREFIX}posts p,
        #            #{TABLE_PREFIX}threads t
        #   WHERE    p.tid = #{m['topic_id']} AND t.tid = #{m['topic_id']}
        #   ORDER BY p.dateline
        #   LIMIT    1
        # ").first['id']

        mapped[:id] = m["id"]
        mapped[:user_id] = user_id_from_imported_user_id(m["user_id"]) || -1
        mapped[:raw] = process_mybb_post(m["raw"], m["id"])
        mapped[:created_at] = Time.zone.at(m["post_time"])

        if m["id"] == m["first_post_id"]
          mapped[:category] = category_id_from_imported_category_id(m["category_id"])
          mapped[:title] = CGI.unescapeHTML(m["title"])
        else
          parent = topic_lookup_from_imported_post_id(m["first_post_id"])
          if parent
            mapped[:topic_id] = parent[:topic_id]
          else
            puts "Parent post #{m["first_post_id"]} doesn't exist. Skipping #{m["id"]}: #{m["title"][0..40]}"
            skip = true
          end
        end

        skip ? nil : mapped
      end
    end
  end

  def import_private_messages
    puts "", "private messages are not implemented"
  end

  def suspend_users
    puts "", "banned users are not implemented"
  end

  # Discourse usernames don't allow spaces
  def convert_username(username, post_id)
    count = 0
    username.gsub!(/\s+/) do |a|
      count += 1
      "_"
    end
    # Warn on MyBB bug that places post text in the quote line - http://community.mybb.com/thread-180526.html
    puts "Warning: probably incorrect quote in post #{post_id}" if count > 5
    username
  end

  # Take an original post id and return the migrated topic id and post number for it
  def post_id_to_post_num_and_topic(quoted_post_id, post_id)
    quoted_post_id_from_imported = post_id_from_imported_post_id(quoted_post_id.to_i)
    if quoted_post_id_from_imported
      begin
        post = Post.find(quoted_post_id_from_imported)
        "post:#{post.post_number}, topic:#{post.topic_id}"
      rescue StandardError
        puts "Could not find migrated post #{quoted_post_id_from_imported} quoted by original post #{post_id} as #{quoted_post_id}"
        ""
      end
    else
      puts "Original post #{post_id} quotes nonexistent post #{quoted_post_id}"
      ""
    end
  end

  def process_mybb_post(raw, import_id)
    s = raw.dup

    # convert the quote line
    s.gsub!(/\[quote='([^']+)'.*?pid='(\d+).*?\]/) do
      "[quote=\"#{convert_username($1, import_id)}, " +
        post_id_to_post_num_and_topic($2, import_id) + '"]'
    end

    # :) is encoded as <!-- s:) --><img src="{SMILIES_PATH}/icon_e_smile.gif" alt=":)" title="Smile" /><!-- s:) -->
    s.gsub!(/<!-- s(\S+) -->(?:.*)<!-- s(?:\S+) -->/, '\1')

    # Some links look like this: <!-- m --><a class="postlink" href="http://www.onegameamonth.com">http://www.onegameamonth.com</a><!-- m -->
    s.gsub!(%r{<!-- \w --><a(?:.+)href="(\S+)"(?:.*)>(.+)</a><!-- \w -->}, '[\2](\1)')

    # Many phpbb bbcode tags have a hash attached to them. Examples:
    #   [url=https&#58;//google&#46;com:1qh1i7ky]click here[/url:1qh1i7ky]
    #   [quote=&quot;cybereality&quot;:b0wtlzex]Some text.[/quote:b0wtlzex]
    s.gsub!(/:(?:\w{8})\]/, "]")

    # Remove mybb video tags.
    s.gsub!(%r{(^\[video=.*?\])|(\[/video\]$)}, "")

    s = CGI.unescapeHTML(s)

    # phpBB shortens link text like this, which breaks our markdown processing:
    #   [http://answers.yahoo.com/question/index ... 223AAkkPli](http://answers.yahoo.com/question/index?qid=20070920134223AAkkPli)
    #
    # Work around it for now:
    s.gsub!(%r{\[http(s)?://(www\.)?}, "[")

    s
  end

  def create_permalinks
    puts "", "Creating redirects...", ""

    SiteSetting.permalink_normalizations = '/(\\w+)-(\\d+)[-.].*/\\1-\\2.html'
    puts "", "Users...", ""
    total_users = User.count
    start_time = Time.now
    count = 0
    User.find_each do |u|
      ucf = u.custom_fields
      count += 1
      if ucf && ucf["import_id"] && ucf["import_username"]
        begin
          Permalink.create(
            url: "#{BASE}/user-#{ucf["import_id"]}.html",
            external_url: "/u/#{u.username}",
          )
        rescue StandardError
          nil
        end
      end
      print_status(count, total_users, start_time)
    end

    puts "", "Categories...", ""
    total_categories = Category.count
    start_time = Time.now
    count = 0
    Category.find_each do |cat|
      ccf = cat.custom_fields
      count += 1
      next unless id = ccf["import_id"]
      puts("forum-#{id}.html --> /c/#{cat.id}") unless QUIET
      begin
        Permalink.create(url: "#{BASE}/forum-#{id}.html", category_id: cat.id)
      rescue StandardError
        nil
      end
      print_status(count, total_categories, start_time)
    end

    puts "", "Topics...", ""
    total_posts = Post.count
    start_time = Time.now
    count = 0
    puts "", "Posts...", ""
    batches(BATCH_SIZE) do |offset|
      results =
        mysql_query(
          "
        SELECT p.pid id,
               p.tid topic_id
          FROM #{TABLE_PREFIX}posts p,
               #{TABLE_PREFIX}threads t
         WHERE p.tid = t.tid
           AND t.firstpost=p.pid
      ORDER BY p.dateline
         LIMIT #{BATCH_SIZE}
        OFFSET #{offset};
      ",
        )
      break if results.size < 1
      results.each do |post|
        count += 1
        if topic = topic_lookup_from_imported_post_id(post["id"])
          id = post["topic_id"]
          begin
            Permalink.create(url: "#{BASE}/thread-#{id}.html", topic_id: topic[:topic_id])
          rescue StandardError
            nil
          end
          unless QUIET
            puts("#{BASE}/thread-#{id}.html --> http://localhost:3000/t/#{topic[:topic_id]}")
          end
          print_status(count, total_posts, start_time)
        end
      end
    end
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end
end

ImportScripts::MyBB.new.perform
