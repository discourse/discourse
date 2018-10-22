require 'mysql2'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'htmlentities'

class ImportScripts::VBulletin < ImportScripts::Base
  BATCH_SIZE = 1000
  DBPREFIX = "vb_"
  ROOT_NODE = 2

  # CHANGE THESE BEFORE RUNNING THE IMPORTER
  DATABASE = "yourforum"
  TIMEZONE = "America/Los_Angeles"
  ATTACHMENT_DIR = '/home/discourse/yourforum/customattachments/'
  AVATAR_DIR = '/home/discourse/yourforum/avatars/'

  def initialize
    super

    @old_username_to_new_usernames = {}

    @tz = TZInfo::Timezone.get(TIMEZONE)

    @htmlentities = HTMLEntities.new

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      database: DATABASE,
      password: "password"
    )

  end

  def execute
    import_groups
    import_users
    import_categories
    import_topics
    import_posts
    import_attachments
    close_topics
    post_process_posts
  end

  def import_groups
    puts "", "importing groups..."

    groups = mysql_query <<-SQL
        SELECT usergroupid, title
          FROM #{DBPREFIX}usergroup
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

    user_count = mysql_query("SELECT COUNT(userid) count FROM #{DBPREFIX}user").first["count"]

    batches(BATCH_SIZE) do |offset|
      users = mysql_query <<-SQL
          SELECT u.userid, u.username, u.homepage, u.usertitle, u.usergroupid, u.joindate, u.email,
            CASE WHEN u.scheme='blowfish:10' THEN token
                 WHEN u.scheme='legacy' THEN REPLACE(token, ' ', ':')
            END AS password,
            IF(ug.title = 'Administrators', 1, 0) AS admin
            FROM #{DBPREFIX}user u
            LEFT JOIN #{DBPREFIX}usergroup ug ON ug.usergroupid = u.usergroupid
        ORDER BY userid
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if users.size < 1

      # disabled line below, caused issues
      # next if all_records_exist? :users, users.map {|u| u["userid"].to_i}

      create_users(users, total: user_count, offset: offset) do |user|
        username = @htmlentities.decode(user["username"]).strip
        {
          id: user["userid"],
          name: username,
          username: username,
          email: user["email"].presence || fake_email,
          admin: user['admin'] == 1,
          password: user["password"],
          website: user["homepage"].strip,
          title: @htmlentities.decode(user["usertitle"]).strip,
          primary_group_id: group_id_from_imported_group_id(user["usergroupid"]),
          created_at: parse_timestamp(user["joindate"]),
          post_create_action: proc do |u|
            @old_username_to_new_usernames[user["username"]] = u.username
            import_profile_picture(user, u)
            import_profile_background(user, u)
          end
        }
      end
    end
  end

  def import_profile_picture(old_user, imported_user)
    query = mysql_query <<-SQL
        SELECT filedata, filename
          FROM #{DBPREFIX}customavatar
         WHERE userid = #{old_user["userid"]}
      ORDER BY dateline DESC
         LIMIT 1
    SQL

    picture = query.first

    return if picture.nil?

    if picture['filedata']
      file = Tempfile.new("profile-picture")
      file.write(picture["filedata"].encode("ASCII-8BIT").force_encoding("UTF-8"))
      file.rewind
      upload = UploadCreator.new(file, picture["filename"]).create_for(imported_user.id)
    else
      filename = File.join(AVATAR_DIR, picture['filename'])
      unless File.exists?(filename)
        puts "Avatar file doesn't exist: #{filename}"
        return nil
      end
      upload = create_upload(imported_user.id, filename, picture['filename'])
    end

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
          FROM #{DBPREFIX}customprofilepic
         WHERE userid = #{old_user["userid"]}
      ORDER BY dateline DESC
         LIMIT 1
    SQL

    background = query.first

    return if background.nil?

    file = Tempfile.new("profile-background")
    file.write(background["filedata"].encode("ASCII-8BIT").force_encoding("UTF-8"))
    file.rewind

    upload = UploadCreator.new(file, background["filename"]).create_for(imported_user.id)

    return if !upload.persisted?

    imported_user.user_profile.update(profile_background: upload.url)
  ensure
    file.close rescue nil
    file.unlink rescue nil
  end

  def import_categories
    puts "", "importing top level categories..."

    categories = mysql_query("SELECT nodeid AS forumid, title, description, displayorder, parentid
	      FROM #{DBPREFIX}node
          WHERE parentid=#{ROOT_NODE}
        UNION
          SELECT nodeid, title, description, displayorder, parentid
          FROM #{DBPREFIX}node
          WHERE contenttypeid = 23
            AND parentid IN (SELECT nodeid FROM #{DBPREFIX}node WHERE parentid=#{ROOT_NODE})").to_a

    top_level_categories = categories.select { |c| c["parentid"] == ROOT_NODE }

    create_categories(top_level_categories) do |category|
      {
        id: category["forumid"],
        name: @htmlentities.decode(category["title"]).strip,
        position: category["displayorder"],
        description: @htmlentities.decode(category["description"]).strip
      }
    end

    puts "", "importing child categories..."

    children_categories = categories.select { |c| c["parentid"] != ROOT_NODE }
    top_level_category_ids = Set.new(top_level_categories.map { |c| c["forumid"] })

    # cut down the tree to only 2 levels of categories
    children_categories.each do |cc|
      while !top_level_category_ids.include?(cc["parentid"])
        cc["parentid"] = categories.detect { |c| c["forumid"] == cc["parentid"] }["parentid"]
      end
    end

    create_categories(children_categories) do |category|
      {
        id: category["forumid"],
        name: @htmlentities.decode(category["title"]).strip,
        position: category["displayorder"],
        description: @htmlentities.decode(category["description"]).strip,
        parent_category_id: category_id_from_imported_category_id(category["parentid"])
      }
    end
  end

  def import_topics
    puts "", "importing topics..."

    # keep track of closed topics
    @closed_topic_ids = []

    topic_count = mysql_query("select count(nodeid) cnt from #{DBPREFIX}node where parentid in (
        select nodeid from #{DBPREFIX}node where contenttypeid=23 ) and contenttypeid=22;").first["cnt"]

    batches(BATCH_SIZE) do |offset|
      topics = mysql_query <<-SQL
        SELECT t.nodeid AS threadid, t.title, t.parentid AS forumid,t.open,t.userid AS postuserid,t.publishdate AS dateline,
            nv.count views, 1 AS visible, t.sticky,
            CONVERT(CAST(rawtext AS BINARY)USING utf8) AS raw
        FROM #{DBPREFIX}node t
        LEFT JOIN #{DBPREFIX}nodeview nv ON nv.nodeid=t.nodeid
        LEFT JOIN #{DBPREFIX}text txt ON txt.nodeid=t.nodeid
        WHERE t.parentid in ( select nodeid from #{DBPREFIX}node where contenttypeid=23 )
          AND t.contenttypeid = 22
        ORDER BY t.nodeid
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if topics.size < 1

      # disabled line below, caused issues
      # next if all_records_exist? :posts, topics.map {|t| "thread-#{topic["threadid"]}" }

      create_posts(topics, total: topic_count, offset: offset) do |topic|
        raw = preprocess_post_raw(topic["raw"]) rescue nil
        next if raw.blank?
        topic_id = "thread-#{topic["threadid"]}"
        @closed_topic_ids << topic_id if topic["open"] == "0"
        t = {
          id: topic_id,
          user_id: user_id_from_imported_user_id(topic["postuserid"]) || Discourse::SYSTEM_USER_ID,
          title: @htmlentities.decode(topic["title"]).strip[0...255],
          category: category_id_from_imported_category_id(topic["forumid"]),
          raw: raw,
          created_at: parse_timestamp(topic["dateline"]),
          visible: topic["visible"].to_i == 1,
          views: topic["views"],
        }
        t[:pinned_at] = t[:created_at] if topic["sticky"].to_i == 1
        t
      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    # make sure `firstpostid` is indexed
    begin
      mysql_query("CREATE INDEX firstpostid_index ON thread (firstpostid)")
    rescue
    end

    post_count = mysql_query("SELECT COUNT(nodeid) cnt FROM #{DBPREFIX}node WHERE parentid NOT IN (
        SELECT nodeid FROM #{DBPREFIX}node WHERE contenttypeid=23 ) AND contenttypeid=22;").first["cnt"]

    batches(BATCH_SIZE) do |offset|
      posts = mysql_query <<-SQL
        SELECT p.nodeid AS postid, p.userid AS userid, p.parentid AS threadid,
            CONVERT(CAST(rawtext AS BINARY)USING utf8) AS raw, p.publishdate AS dateline,
            1 AS visible, p.parentid AS parentid
        FROM #{DBPREFIX}node p
        LEFT JOIN #{DBPREFIX}nodeview nv ON nv.nodeid=p.nodeid
        LEFT JOIN #{DBPREFIX}text txt ON txt.nodeid=p.nodeid
        WHERE p.parentid NOT IN ( select nodeid from #{DBPREFIX}node where contenttypeid=23 )
          AND p.contenttypeid = 22
        ORDER BY postid
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if posts.size < 1

      # disabled line below, caused issues
      # next if all_records_exist? :posts, posts.map {|p| p["postid"] }

      create_posts(posts, total: post_count, offset: offset) do |post|
        raw = preprocess_post_raw(post["raw"])
        next if raw.blank?
        next unless topic = topic_lookup_from_imported_post_id("thread-#{post["threadid"]}")
        p = {
          id: post["postid"],
          user_id: user_id_from_imported_user_id(post["userid"]) || Discourse::SYSTEM_USER_ID,
          topic_id: topic[:topic_id],
          raw: raw,
          created_at: parse_timestamp(post["dateline"]),
          hidden: post["visible"].to_i == 0,
        }
        if parent = topic_lookup_from_imported_post_id(post["parentid"])
          p[:reply_to_post_number] = parent[:post_number]
        end
        p
      end
    end
  end

  # find the uploaded file information from the db
  def find_upload(post, attachment_id)
    sql = "SELECT a.filedataid, a.filename, fd.userid, LENGTH(fd.filedata) AS dbsize, filedata
             FROM #{DBPREFIX}attach a
             LEFT JOIN #{DBPREFIX}filedata fd ON fd.filedataid = a.filedataid
            WHERE a.nodeid = #{attachment_id}"
    results = mysql_query(sql)

    unless (row = results.first)
      puts "Couldn't find attachment record for post.id = #{post.id}, import_id = #{post.custom_fields['import_id']}"
      return nil
    end

    filename = File.join(ATTACHMENT_DIR, row['userid'].to_s.split('').join('/'), "#{row['filedataid']}.attach")
    real_filename = row['filename']
    real_filename.prepend SecureRandom.hex if real_filename[0] == '.'

    unless File.exists?(filename)
      if row['dbsize'].to_i == 0
        puts "Attachment file #{row['filedataid']} doesn't exist"
        return nil
      end

      tmpfile = 'attach_' + row['filedataid'].to_s
      filename = File.join('/tmp/', tmpfile)
      File.open(filename, 'wb') { |f|
        #f.write(PG::Connection.unescape_bytea(row['filedata']))
        f.write(row['filedata'])
      }
    end

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
    total_count = mysql_query("SELECT COUNT(nodeid) cnt FROM #{DBPREFIX}node WHERE contenttypeid=22 ").first["cnt"]

    success_count = 0
    fail_count = 0

    attachment_regex = /\[attach[^\]]*\]n(\d+)\[\/attach\]/i

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
        PostRevisor.new(post).revise!(post.user, { raw: new_raw }, bypass_bump: true, edit_reason: 'Import attachments from vBulletin')
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

    DB.exec(sql, @closed_topic_ids)
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
    raw.gsub!(/\[url="?(.+?)"?\](.+?)\[\/url\]/i) { "<a href=\"#{$1}\">#{$2}</a>" }

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

    # [USER=<user_id>]<username>[/USER]
    raw = raw.gsub(/\[user="?(\d+)"?\](.+?)\[\/user\]/i) do
      user_id, old_username = $1, $2
      if @old_username_to_new_usernames.has_key?(old_username)
        new_username = @old_username_to_new_usernames[old_username]
      else
        new_username = old_username
      end
      "@#{new_username}"
    end

    # [FONT=blah] and [COLOR=blah]
    # no idea why the /i is not matching case insensitive..
    raw.gsub! /\[color=.*?\](.*?)\[\/color\]/im, '\1'
    raw.gsub! /\[COLOR=.*?\](.*?)\[\/COLOR\]/im, '\1'
    raw.gsub! /\[font=.*?\](.*?)\[\/font\]/im, '\1'
    raw.gsub! /\[FONT=.*?\](.*?)\[\/FONT\]/im, '\1'

    # [CENTER]...[/CENTER]
    raw.gsub! /\[CENTER\](.*?)\[\/CENTER\]/im, '\1'

    # fix LIST
    raw.gsub! /\[LIST\](.*?)\[\/LIST\]/im, '<ul>\1</ul>'
    raw.gsub! /\[\*\]/im, '<li>'

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
    raw = raw.gsub(/\[quote=([^;]+);n(\d+)\](.+?)\[\/quote\]/im) do
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

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end

end

ImportScripts::VBulletin.new.perform
