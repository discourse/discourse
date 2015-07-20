# Notes:
#
# Written by Sam
#
# Lithium are quite protective of data, there is no simple way of exporting
# If you have leverage you may get a data dump, in my case it was provided in XML
# format
#
# First step is to convert it to db format so you can import it into a DB
# that was done using import_scripts/support/convert_mysql_xml_to_mysql.rb
#



require 'mysql2'
require 'reverse_markdown'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'htmlentities'

# remove table conversion
[:table,:td,:tr,:th,:thead,:tbody].each do |tag|
  ReverseMarkdown::Converters.unregister(tag)
end

class ImportScripts::Lithium < ImportScripts::Base
  BATCH_SIZE = 1000

  # CHANGE THESE BEFORE RUNNING THE IMPORTER
  DATABASE = "wd"
  PASSWORD = "password"
  TIMEZONE = "Asia/Kolkata"
  ATTACHMENT_DIR = '/path/to/your/attachment/folder'


  TEMP = ""

  def initialize
    super

    @old_username_to_new_usernames = {}

    @tz = TZInfo::Timezone.get(TIMEZONE)

    @htmlentities = HTMLEntities.new

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      password: PASSWORD,
      database: DATABASE
    )
  end

  def execute

    # import_users
    # import_categories
    # import_topics
    # import_posts
    # import_likes
    import_accepted_answers

    # import_attachments
    #
    # close_topics
    post_process_posts
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
        id: group["usergroupid"],
        name: @htmlentities.decode(group["title"]).strip
      }
    end
  end

  def import_users
    puts "", "importing users"

    user_count = mysql_query("SELECT COUNT(*) count FROM users").first["count"]

    batches(BATCH_SIZE) do |offset|
      users = mysql_query <<-SQL
          SELECT id, nlogin, login_canon, email, registration_time
            FROM users
        ORDER BY id
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if users.size < 1

      create_users(users, total: user_count, offset: offset) do |user|

        {
          id: user["id"],
          name: user["nlogin"],
          username: user["login-canon"],
          email: user["email"].presence || fake_email,
          # website: user["homepage"].strip,
          # title: @htmlentities.decode(user["usertitle"]).strip,
          # primary_group_id: group_id_from_imported_group_id(user["usergroupid"]),
          created_at: unix_time(user["registration_time"]),
          # post_create_action: proc do |u|
          #   @old_username_to_new_usernames[user["username"]] = u.username
          #   import_profile_picture(user, u)
          #   import_profile_background(user, u)
          # end
        }
      end
    end
  end

  def unix_time(t)
    Time.at(t/1000.0)
  end

  def import_profile_picture(old_user, imported_user)
    query = mysql_query <<-SQL
        SELECT filedata, filename
          FROM customavatar
         WHERE userid = #{old_user["userid"]}
      ORDER BY dateline DESC
         LIMIT 1
    SQL

    picture = query.first

    return if picture.nil?

    file = Tempfile.new("profile-picture")
    file.write(picture["filedata"].encode("ASCII-8BIT").force_encoding("UTF-8"))
    file.rewind

    upload = Upload.create_for(imported_user.id, file, picture["filename"], file.size)

    return if !upload.persisted?

    imported_user.create_user_avatar
    imported_user.user_avatar.update(custom_upload_id: upload.id)
    imported_user.update(uploaded_avatar_id: upload.id)
  ensure
    file.close rescue nil
    file.unlind rescue nil
  end

  def import_profile_background(old_user, imported_user)
    query = mysql_query <<-SQL
        SELECT filedata, filename
          FROM customprofilepic
         WHERE userid = #{old_user["userid"]}
      ORDER BY dateline DESC
         LIMIT 1
    SQL

    background = query.first

    return if background.nil?

    file = Tempfile.new("profile-background")
    file.write(background["filedata"].encode("ASCII-8BIT").force_encoding("UTF-8"))
    file.rewind

    upload = Upload.create_for(imported_user.id, file, background["filename"], file.size)

    return if !upload.persisted?

    imported_user.user_profile.update(profile_background: upload.url)
  ensure
    file.close rescue nil
    file.unlink rescue nil
  end

  def import_categories
    puts "", "importing top level categories..."

    categories = mysql_query("SELECT node_id, display_id, position, parent_node_id from nodes").to_a

    # HACK
    top_level_categories = categories.select { |c| c["parent_node_id"] == 2 }

    create_categories(top_level_categories) do |category|
      {
        id: category["node_id"],
        name: category["display_id"],
        position: category["position"]
        # description:
      }
    end


    puts "", "importing children categories..."

    children_categories = categories.select { |c| ![1,2].include?(c["parent_node_id"]) && ![1,2].include?(c["node_id"]) }

    top_level_category_ids = Set.new(top_level_categories.map { |c| c["node_id"] })

    # cut down the tree to only 2 levels of categories
    children_categories.each do |cc|
      while !top_level_category_ids.include?(cc["parent_node_id"])
        cc["parent_node_id"] = categories.detect { |c| c["node_id"] == cc["parent_node_id"] }["parent_node_id"]
      end
    end

    create_categories(children_categories) do |category|
      {
        id: category["node_id"],
        name: category["display_id"],
        position: category["position"],
        # description: ,
        parent_category_id: category_id_from_imported_category_id(category["parent_node_id"])
      }
    end
  end

  def import_topics
    puts "", "importing topics..."

    # # keep track of closed topics
    # @closed_topic_ids = []

    topic_count = mysql_query("SELECT COUNT(*) count FROM message2 where id = root_id").first["count"]

    batches(BATCH_SIZE) do |offset|
      topics = mysql_query <<-SQL
          SELECT id, subject, body, deleted, user_id,
                 post_date, views, node_id, unique_id
            FROM message2
        WHERE id = root_id #{TEMP} AND deleted = 0
        ORDER BY node_id, id
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL


      break if topics.size < 1

      create_posts(topics, total: topic_count, offset: offset) do |topic|

        # @closed_topic_ids << topic_id if topic["open"] == "0"

        raw = to_markdown(topic["body"])

        {
          id: "#{topic["node_id"]} #{topic["id"]}",
          user_id: user_id_from_imported_user_id(topic["user_id"]) || Discourse::SYSTEM_USER_ID,
          title: @htmlentities.decode(topic["subject"]).strip[0...255],
          category: category_id_from_imported_category_id(topic["node_id"]),
          raw: raw,
          created_at: unix_time(topic["post_date"]),
          views: topic["views"],
          custom_fields: {import_unique_id: topic["unique_id"]},
          import_mode: true
        }

      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    post_count = mysql_query("SELECT COUNT(*) count FROM message2
                              WHERE id <> root_id").first["count"]

    batches(BATCH_SIZE) do |offset|
      posts = mysql_query <<-SQL
          SELECT id, body, deleted, user_id,
                 post_date, parent_id, root_id, node_id, unique_id
            FROM message2
        WHERE id <> root_id #{TEMP} AND deleted = 0
        ORDER BY node_id, root_id, id
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if posts.size < 1

      create_posts(posts, total: post_count, offset: offset) do |post|
        raw = preprocess_post_raw(post["raw"]) rescue nil
        next unless topic = topic_lookup_from_imported_post_id("#{post["node_id"]} #{post["root_id"]}")

        raw = to_markdown(post["body"])

        new_post = {
          id: "#{post["node_id"]} #{post["root_id"]} #{post["id"]}",
          user_id: user_id_from_imported_user_id(post["user_id"]) || Discourse::SYSTEM_USER_ID,
          topic_id: topic[:topic_id],
          raw: raw,
          created_at: unix_time(post["post_date"]),
          custom_fields: {import_unique_id: post["unique_id"]},
          import_mode: true
        }

        if post["deleted"] > 0
          new_post["deleted_at"] = Time.now
        end

        if parent = topic_lookup_from_imported_post_id("#{post["node_id"]} #{post["root_id"]} #{post["parent_id"]}")
          new_post[:reply_to_post_number] = parent[:post_number]
        end

        new_post
      end
    end
  end

  def to_markdown(html)
    raw = ReverseMarkdown.convert(html)
    raw.gsub!(/^\s*&nbsp;\s*$/, "")
    # ugly quotes
    raw.gsub!(/^>[\s\*]*$/, "")
    raw.gsub!(":smileysad:", ":frowning:")
    raw.gsub!(":smileyhappy:", ":smile:")
    raw.gsub!(":smileyvery-happy:", ":smiley:")
    # nbsp central
    raw.gsub!(/([a-zA-Z0-9])&nbsp;([a-zA-Z0-9])/,"\\1 \\2")
    raw
  end

  def import_likes
    puts "\nimporting likes..."

    sql = "select source_id user_id, target_id post_id, row_version created_at from wd.tag_events_score_message"
    results = mysql_query(sql)

    puts "loading unique id map"
    existing_map = {}
    PostCustomField.where(name: 'import_unique_id').pluck(:post_id, :value).each do |post_id, import_id|
      existing_map[import_id] = post_id
    end



    puts "loading data into temp table"
    PostAction.exec_sql("create temp table like_data(user_id int, post_id int, created_at timestamp without time zone)")
    PostAction.transaction do
      results.each do |result|

        result["user_id"] = user_id_from_imported_user_id(result["user_id"].to_s)
        result["post_id"] = existing_map[result["post_id"].to_s]

        next unless result["user_id"] && result["post_id"]

        PostAction.exec_sql("INSERT INTO like_data VALUES (:user_id,:post_id,:created_at)",
                              user_id: result["user_id"],
                              post_id: result["post_id"],
                              created_at: result["created_at"]
                           )

      end
    end

    puts "creating missing post actions"
    PostAction.exec_sql <<-SQL

    INSERT INTO post_actions (post_id, user_id, post_action_type_id, created_at, updated_at)
             SELECT l.post_id, l.user_id, 2, l.created_at, l.created_at FROM like_data l
             LEFT JOIN post_actions a ON a.post_id = l.post_id AND l.user_id = a.user_id AND a.post_action_type_id = 2
             WHERE a.id IS NULL
    SQL

    puts "creating missing user actions"
    UserAction.exec_sql <<-SQL
    INSERT INTO user_actions (user_id, action_type, target_topic_id, target_post_id, acting_user_id, created_at, updated_at)
             SELECT pa.user_id, 1, p.topic_id, p.id, pa.user_id, pa.created_at, pa.created_at
             FROM post_actions pa
             JOIN posts p ON p.id = pa.post_id
             LEFT JOIN user_actions ua ON action_type = 1 AND ua.target_post_id = pa.post_id AND ua.user_id = pa.user_id

             WHERE ua.id IS NULL AND pa.post_action_type_id = 2
    SQL


    # reverse action
    UserAction.exec_sql <<-SQL
    INSERT INTO user_actions (user_id, action_type, target_topic_id, target_post_id, acting_user_id, created_at, updated_at)
             SELECT p.user_id, 2, p.topic_id, p.id, pa.user_id, pa.created_at, pa.created_at
             FROM post_actions pa
             JOIN posts p ON p.id = pa.post_id
             LEFT JOIN user_actions ua ON action_type = 2 AND ua.target_post_id = pa.post_id AND
                ua.acting_user_id = pa.user_id AND ua.user_id = p.user_id

             WHERE ua.id IS NULL AND pa.post_action_type_id = 2
    SQL
    puts "updating like counts on posts"

    Post.exec_sql <<-SQL
        UPDATE posts SET like_count = coalesce(cnt,0)
                  FROM (
        SELECT post_id, count(*) cnt
        FROM post_actions
        WHERE post_action_type_id = 2 AND deleted_at IS NULL
        GROUP BY post_id
    ) x
    WHERE posts.like_count <> x.cnt AND posts.id = x.post_id

    SQL

    puts "updating like counts on topics"

    Post.exec_sql <<-SQL
      UPDATE topics SET like_count = coalesce(cnt,0)
      FROM (
        SELECT topic_id, sum(like_count) cnt
        FROM posts
        WHERE deleted_at IS NULL
        GROUP BY topic_id
      ) x
      WHERE topics.like_count <> x.cnt AND topics.id = x.topic_id

    SQL
  end

  def import_accepted_answers

    puts "\nimporting accepted answers..."

    sql = "select unique_id post_id from message2 where (attributes & 0x4000 ) != 0 and deleted = 0;"
    results = mysql_query(sql)

    puts "loading unique id map"
    existing_map = {}
    PostCustomField.where(name: 'import_unique_id').pluck(:post_id, :value).each do |post_id, import_id|
      existing_map[import_id] = post_id
    end


    puts "loading data into temp table"
    PostAction.exec_sql("create temp table accepted_data(post_id int primary key)")
    PostAction.transaction do
      results.each do |result|

        result["post_id"] = existing_map[result["post_id"].to_s]

        next unless result["post_id"]

        PostAction.exec_sql("INSERT INTO accepted_data VALUES (:post_id)",
                              post_id: result["post_id"]
                           )

      end
    end


    puts "deleting dupe answers"
    PostAction.exec_sql <<-SQL
    DELETE FROM accepted_data WHERE post_id NOT IN (
      SELECT post_id FROM
      (
        SELECT topic_id, MIN(post_id) post_id
        FROM accepted_data a
        JOIN posts p ON p.id = a.post_id
        GROUP BY topic_id
      ) X
    )
    SQL

    puts "importing accepted answers"
    PostAction.exec_sql <<-SQL
      INSERT into post_custom_fields (name, value, post_id, created_at, updated_at)
      SELECT 'is_accepted_answer', 'true', a.post_id, current_timestamp, current_timestamp
      FROM accepted_data a
      LEFT JOIN post_custom_fields f ON name = 'is_accepted_answer' AND f.post_id = a.post_id
      WHERE f.id IS NULL
    SQL

    puts "marking accepted topics"
    PostAction.exec_sql <<-SQL
      INSERT into topic_custom_fields (name, value, topic_id, created_at, updated_at)
      SELECT 'accepted_answer_post_id', a.post_id::varchar, p.topic_id, current_timestamp, current_timestamp
      FROM accepted_data a
      JOIN posts p ON p.id = a.post_id
      LEFT JOIN topic_custom_fields f ON name = 'accepted_answer_post_id' AND f.topic_id = p.topic_id
      WHERE f.id IS NULL
    SQL
    puts "done importing accepted answers"
  end

  # find the uploaded file information from the db
  def find_upload(post, attachment_id)
    sql = "SELECT a.attachmentid attachment_id, a.userid user_id, a.filedataid file_id, a.filename filename,
                  a.caption caption
             FROM attachment a
            WHERE a.attachmentid = #{attachment_id}"
    results = mysql_query(sql)

    unless (row = results.first)
      puts "Couldn't find attachment record for post.id = #{post.id}, import_id = #{post.custom_fields['import_id']}"
      return nil
    end

    filename = File.join(ATTACHMENT_DIR, row['user_id'].to_s.split('').join('/'), "#{row['file_id']}.attach")
    unless File.exists?(filename)
      puts "Attachment file doesn't exist: #{filename}"
      return nil
    end
    real_filename = row['filename']
    real_filename.prepend SecureRandom.hex if real_filename[0] == '.'
    upload = create_upload(post.user.id, filename, real_filename)

    if upload.nil? || !upload.valid?
      puts "Upload not valid :("
      puts upload.errors.inspect if upload
      return nil
    end

    return upload, real_filename
  rescue Mysql2::Error => e
    puts "SQL Error"
    puts e.message
    puts sql
    return nil
  end

  def import_attachments
    puts '', 'importing attachments...'

    current_count = 0
    total_count = mysql_query("SELECT COUNT(postid) count FROM post WHERE postid NOT IN (SELECT firstpostid FROM thread)").first["count"]

    success_count = 0
    fail_count = 0

    attachment_regex = /\[attach[^\]]*\](\d+)\[\/attach\]/i

    Post.find_each do |post|
      current_count += 1
      print_status current_count, total_count

      new_raw = post.raw.dup
      new_raw.gsub!(attachment_regex) do |s|
        matches = attachment_regex.match(s)
        attachment_id = matches[1]

        upload, filename = find_upload(post, attachment_id)
        unless upload
          fail_count += 1
          next
        end

        html_for_upload(upload, filename)
      end

      if new_raw != post.raw
        PostRevisor.new(post).revise!(post.user, { raw: new_raw }, { bypass_bump: true, edit_reason: 'Import attachments from vBulletin' })
      end

      success_count += 1
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

  def post_process_posts
    puts "", "Postprocessing posts..."

    current = 0
    max = Post.count

    Post.find_each do |post|
      begin
        new_raw = postprocess_post_raw(post.raw)
        if new_raw != post.raw
          post.raw = new_raw
          post.save
        end
      rescue PrettyText::JavaScriptError
        nil
      ensure
        print_status(current += 1, max)
      end
    end
  end

  def preprocess_post_raw(raw)
    return "" if raw.blank?

    # decode HTML entities
    raw = @htmlentities.decode(raw)

    # fix whitespaces
    raw = raw.gsub(/(\\r)?\\n/, "\n")
             .gsub("\\t", "\t")

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

  def postprocess_post_raw(raw)
    # [QUOTE=<username>;<post_id>]...[/QUOTE]
    raw = raw.gsub(/\[quote=([^;]+);(\d+)\](.+?)\[\/quote\]/im) do
      old_username, post_id, quote = $1, $2, $3

      if @old_username_to_new_usernames.has_key?(old_username)
        old_username = @old_username_to_new_usernames[old_username]
      end

      if topic_lookup = topic_lookup_from_imported_post_id(post_id)
        post_number = topic_lookup[:post_number]
        topic_id    = topic_lookup[:topic_id]
        "\n[quote=\"#{old_username},post:#{post_number},topic:#{topic_id}\"]\n#{quote}\n[/quote]\n"
      else
        "\n[quote=\"#{old_username}\"]\n#{quote}\n[/quote]\n"
      end
    end

    # remove attachments
    raw = raw.gsub(/\[attach[^\]]*\]\d+\[\/attach\]/i, "")

    # [THREAD]<thread_id>[/THREAD]
    # ==> http://my.discourse.org/t/slug/<topic_id>
    raw = raw.gsub(/\[thread\](\d+)\[\/thread\]/i) do
      thread_id = $1
      if topic_lookup = topic_lookup_from_imported_post_id("thread-#{thread_id}")
        topic_lookup[:url]
      else
        $&
      end
    end

    # [THREAD=<thread_id>]...[/THREAD]
    # ==> [...](http://my.discourse.org/t/slug/<topic_id>)
    raw = raw.gsub(/\[thread=(\d+)\](.+?)\[\/thread\]/i) do
      thread_id, link = $1, $2
      if topic_lookup = topic_lookup_from_imported_post_id("thread-#{thread_id}")
        url = topic_lookup[:url]
        "[#{link}](#{url})"
      else
        $&
      end
    end

    # [POST]<post_id>[/POST]
    # ==> http://my.discourse.org/t/slug/<topic_id>/<post_number>
    raw = raw.gsub(/\[post\](\d+)\[\/post\]/i) do
      post_id = $1
      if topic_lookup = topic_lookup_from_imported_post_id(post_id)
        topic_lookup[:url]
      else
        $&
      end
    end

    # [POST=<post_id>]...[/POST]
    # ==> [...](http://my.discourse.org/t/<topic_slug>/<topic_id>/<post_number>)
    raw = raw.gsub(/\[post=(\d+)\](.+?)\[\/post\]/i) do
      post_id, link = $1, $2
      if topic_lookup = topic_lookup_from_imported_post_id(post_id)
        url = topic_lookup[:url]
        "[#{link}](#{url})"
      else
        $&
      end
    end

    raw
  end

  def parse_timestamp(timestamp)
    Time.zone.at(@tz.utc_to_local(timestamp))
  end

  def fake_email
    SecureRandom.hex << "@domain.com"
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end

end

ImportScripts::Lithium.new.perform
