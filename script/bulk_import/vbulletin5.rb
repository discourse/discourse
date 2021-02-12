# frozen_string_literal: true

require_relative "base"
require "set"
require "mysql2"
require "htmlentities"
require 'ruby-bbcode-to-md'

class BulkImport::VBulletin5 < BulkImport::Base

  DB_PREFIX = ""
  SUSPENDED_TILL ||= Date.new(3000, 1, 1)
  ATTACH_DIR ||= ENV['ATTACH_DIR'] || '/shared/import/data/attachments'
  AVATAR_DIR ||= ENV['AVATAR_DIR'] || '/shared/import/data/customavatars'
  ROOT_NODE = 2

  def initialize
    super

    host     = ENV["DB_HOST"] || "localhost"
    username = ENV["DB_USERNAME"] || "root"
    password = ENV["DB_PASSWORD"]
    database = ENV["DB_NAME"] || "vbulletin"
    charset  = ENV["DB_CHARSET"] || "utf8"

    @html_entities = HTMLEntities.new
    @encoding = CHARSET_MAP[charset]
    @bbcode_to_md = true

    @client = Mysql2::Client.new(
      host: host,
      username: username,
      password: password,
      database: database,
      encoding: charset,
      reconnect: true
    )

    @client.query_options.merge!(as: :array, cache_rows: false)

    @forum_typeid = mysql_query("SELECT contenttypeid FROM #{DB_PREFIX}contenttype WHERE class='Forum'").to_a[0][0]
    @channel_typeid = mysql_query("SELECT contenttypeid FROM #{DB_PREFIX}contenttype WHERE class='Channel'").to_a[0][0]
    @text_typeid = mysql_query("SELECT contenttypeid FROM #{DB_PREFIX}contenttype WHERE class='Text'").to_a[0][0]
  end

  def execute
    # enable as per requirement:
    # SiteSetting.automatic_backups_enabled = false
    # SiteSetting.disable_emails = "non-staff"
    # SiteSetting.authorized_extensions = '*'
    # SiteSetting.max_image_size_kb = 102400
    # SiteSetting.max_attachment_size_kb = 102400
    # SiteSetting.clean_up_uploads = false
    # SiteSetting.clean_orphan_uploads_grace_period_hours = 43200

    #import_groups
    #import_users
    #import_group_users

    #import_user_emails
    #import_user_stats
    #import_user_profiles
    #import_user_account_id

    #import_categories
    #import_topics
    #import_topic_first_posts
    #import_replies

    #import_likes

    #import_private_topics
    #import_topic_allowed_users
    #import_private_first_posts
    #import_private_replies
    
    #create_oauth_records

    # --- need writing below
    #create_permalink_file
    import_attachments
    #import_avatars
  end

  def import_groups
    puts "Importing groups..."

    groups = mysql_stream <<-SQL
        SELECT usergroupid, title, description, usertitle
          FROM #{DB_PREFIX}usergroup
         WHERE usergroupid > #{@last_imported_group_id}
      ORDER BY usergroupid
    SQL

    create_groups(groups) do |row|
      {
        imported_id: row[0],
        name: normalize_text(row[1]),
        bio_raw: normalize_text(row[2]),
        title: normalize_text(row[3]),
      }
    end
  end

  def import_users
    puts "Importing users..."

    users = mysql_stream <<-SQL
        SELECT u.userid, u.username, u.joindate, u.birthday, 
               u.ipaddress, u.usergroupid, ub.bandate, ub.liftdate, u.email
          FROM #{DB_PREFIX}user u
     LEFT JOIN #{DB_PREFIX}userban ub ON ub.userid = u.userid
         WHERE u.userid > #{@last_imported_user_id}
      ORDER BY u.userid
    SQL

    create_users(users) do |row|
      u = {
        imported_id: row[0],
        username: normalize_text(row[1].truncate(60)),
        name: normalize_text(row[1]),
        email: row[8],
        created_at: Time.zone.at(row[2]),
        date_of_birth: parse_birthday(row[3]),
        primary_group_id: group_id_from_imported_id(row[5]),
        admin: row[5] == 6,
        moderator: row[5] == 7
      }
      u[:ip_address] = row[4][/\b(?:\d{1,3}\.){3}\d{1,3}\b/] if row[4].present?
      if row[7]
        u[:suspended_at] = Time.zone.at(row[6])
        u[:suspended_till] = row[7] > 0 ? Time.zone.at(row[7]) : SUSPENDED_TILL
      end
      u
    end
  end

  def import_user_account_id
    puts "Importing user account ids..."

    users = mysql_stream <<-SQL
      SELECT u.userid, u.account_id
        FROM #{DB_PREFIX}user u
       ORDER BY u.userid
    SQL

    create_custom_fields("user", "account_id", users) do |row|
      user_id = user_id_from_imported_id(row[0])
      next if user_id.nil?
      { 
        record_id: user_id,
        value: row[1]
      }
    end
  end

  def import_user_emails
    puts "Importing user emails..."

    users = mysql_stream <<-SQL
        SELECT u.userid, u.email, u.joindate
          FROM #{DB_PREFIX}user u
         WHERE u.userid > #{@last_imported_user_id}
      ORDER BY u.userid
    SQL

    create_user_emails(users) do |row|
      {
        imported_id: row[0],
        imported_user_id: row[0],
        email: random_email,
        created_at: Time.zone.at(row[2])
      }
    end
  end

  def import_user_stats
    puts "Importing user stats..."

    users = mysql_stream <<-SQL
      SELECT u.userid, u.joindate, u.posts,
             SUM(
               CASE
                 WHEN n.contenttypeid = #{@text_typeid}
                  AND n.parentid IN ( select nodeid from #{DB_PREFIX}node where contenttypeid=#{@channel_typeid} )
                 THEN 1
                 ELSE 0
               END
             ) AS threads
        FROM #{DB_PREFIX}user u
        LEFT OUTER JOIN #{DB_PREFIX}node n ON u.userid = n.userid
       WHERE u.userid > #{@last_imported_user_id}
       GROUP BY u.userid
       ORDER BY u.userid
    SQL

    create_user_stats(users) do |row|
      user = {
        imported_id: row[0],
        imported_user_id: row[0],
        new_since: Time.zone.at(row[1]),
        post_count: row[2],
        topic_count: row[3],
      }

      user
    end
  end

  def import_group_users
    puts "Importing group users..."

    group_users = mysql_stream <<-SQL
      SELECT usergroupid, userid
        FROM #{DB_PREFIX}user
       WHERE userid > #{@last_imported_user_id}
    SQL

    create_group_users(group_users) do |row|
      {
        group_id: group_id_from_imported_id(row[0]),
        user_id: user_id_from_imported_id(row[1]),
      }
    end
  end

  def import_user_profiles
    puts "Importing user profiles..."

    user_profiles = mysql_stream <<-SQL
        SELECT userid, homepage, profilevisits
          FROM #{DB_PREFIX}user
         WHERE userid > #{@last_imported_user_id}
      ORDER BY userid
    SQL

    create_user_profiles(user_profiles) do |row|
      {
        user_id: user_id_from_imported_id(row[0]),
        website: (URI.parse(row[1]).to_s rescue nil),
        views: row[2],
      }
    end
  end

  def import_categories
    puts "Importing categories..."

    categories = mysql_query(<<-SQL
      SELECT nodeid AS forumid, title, description, displayorder, parentid
        FROM #{DB_PREFIX}node
       WHERE parentid = #{ROOT_NODE}
       UNION
         SELECT nodeid, title, description, displayorder, parentid
           FROM #{DB_PREFIX}node
          WHERE contenttypeid = #{@channel_typeid}
            AND parentid IN (SELECT nodeid FROM #{DB_PREFIX}node WHERE parentid = #{ROOT_NODE})
    SQL
    ).to_a

    return if categories.empty?

    parent_categories   = categories.select { |c| c[4] == ROOT_NODE }
    children_categories = categories.select { |c| c[4] != ROOT_NODE }

    parent_category_ids = Set.new parent_categories.map { |c| c[0] }

    # cut down the tree to only 2 levels of categories
    children_categories.each do |cc|
      until parent_category_ids.include?(cc[4])
        cc[4] = categories.find { |c| c[0] == cc[4] }[4]
      end
    end

    puts "Importing parent categories..."
    create_categories(parent_categories) do |row|
      {
        imported_id: row[0],
        name: normalize_text(row[1]),
        description: normalize_text(row[2]),
        position: row[3],
      }
    end

    puts "Importing children categories..."
    create_categories(children_categories) do |row|
      {
        imported_id: row[0],
        name: normalize_text(row[1]),
        description: normalize_text(row[2]),
        position: row[3],
        parent_category_id: category_id_from_imported_id(row[4]),
      }
    end
  end

  def import_topics
    puts "Importing topics..."

    topics = mysql_stream <<-SQL
      SELECT t.nodeid AS threadid, t.title, t.parentid AS forumid,
             t.open, t.userid AS postuserid, t.publishdate AS dateline,
             nv.count views, 1 AS visible, t.sticky
            FROM #{DB_PREFIX}node t
       LEFT JOIN #{DB_PREFIX}nodeview nv ON nv.nodeid = t.nodeid
           WHERE t.parentid IN (SELECT nodeid from #{DB_PREFIX}node WHERE contenttypeid = #{@channel_typeid} )
             AND t.contenttypeid = #{@text_typeid}
             AND t.parentid != 7
             AND (t.unpublishdate = 0 OR t.unpublishdate IS NULL)
             AND t.approved = 1 AND t.showapproved = 1
             AND t.nodeid > #{@last_imported_topic_id}
        ORDER BY t.nodeid
    SQL

    create_topics(topics) do |row|
      created_at = Time.zone.at(row[5])

      title = normalize_text(row[1])

      t = {
        imported_id: row[0],
        title: title,
        category_id: category_id_from_imported_id(row[2]),
        user_id: user_id_from_imported_id(row[4]),
        closed: row[3] == 0,
        created_at: created_at,
        views: row[6],
        visible: row[7] == 1,
      }

      t[:pinned_at] = created_at if row[8] == 1

      t
    end

  end

  def import_topic_first_posts
    puts "Importing topic first posts..."

    topics = mysql_stream <<-SQL
      SELECT t.nodeid, t.parentid, t.userid, 
             t.publishdate, 1 AS visible, rawtext
            FROM #{DB_PREFIX}node t
       LEFT JOIN #{DB_PREFIX}nodeview nv ON nv.nodeid = t.nodeid
       LEFT JOIN #{DB_PREFIX}text txt ON txt.nodeid = t.nodeid
           WHERE t.parentid IN (SELECT nodeid from #{DB_PREFIX}node WHERE contenttypeid = #{@channel_typeid} )
             AND t.contenttypeid = #{@text_typeid}
             AND t.parentid != 7
             AND (t.unpublishdate = 0 OR t.unpublishdate IS NULL)
             AND t.approved = 1 AND t.showapproved = 1
        ORDER BY t.nodeid
    SQL

    create_posts(topics) do |row|
      post = {
        imported_id: row[0],
        user_id: user_id_from_imported_id(row[2]),
        topic_id: topic_id_from_imported_id(row[0]),
        created_at: Time.zone.at(row[3]),
        hidden: row[4] != 1,
        raw: preprocess_raw(row[5]),
      }

      post
    end
  end

  def import_replies
    puts "Importing replies..."

    posts = mysql_stream <<-SQL
      SELECT p.nodeid, p.userid, p.parentid,
             CONVERT(CAST(rawtext AS BINARY)USING utf8),
             p.publishdate, 1 AS visible, p.parentid
        FROM #{DB_PREFIX}node p
        LEFT JOIN #{DB_PREFIX}nodeview nv ON nv.nodeid = p.nodeid
        LEFT JOIN #{DB_PREFIX}text txt ON txt.nodeid = p.nodeid
       WHERE p.parentid NOT IN (SELECT nodeid FROM #{DB_PREFIX}node WHERE contenttypeid = #{@channel_typeid} )
         AND p.contenttypeid = #{@text_typeid}
         AND p.nodeid > #{@last_imported_post_id}
       ORDER BY p.nodeid
    SQL

    create_posts(posts) do |row|
      
      post = {
        imported_id: row[0],
        user_id: user_id_from_imported_id(row[1]),
        topic_id: topic_id_from_imported_id(row[2]) || row[0],
        created_at: Time.zone.at(row[4]),
        hidden: row[5] == 0,
        raw: preprocess_raw(row[3]),
      }

      post
    end
  end

  def import_likes
    puts "Importing likes..."

    @imported_likes = Set.new
    @last_imported_post_id = 0

    post_likes = mysql_stream <<-SQL
        SELECT nodeid, userid, dateline
          FROM #{DB_PREFIX}reputation
         WHERE nodeid > #{@last_imported_post_id}
      ORDER BY nodeid
    SQL

    create_post_actions(post_likes) do |row|
      post_id = post_id_from_imported_id(row[0])
      user_id = user_id_from_imported_id(row[1])

      next if post_id.nil? || user_id.nil?
      next if @imported_likes.add?([post_id, user_id]).nil?

      {
        post_id: post_id_from_imported_id(row[0]),
        user_id: user_id_from_imported_id(row[1]),
        post_action_type_id: 2,
        created_at: Time.zone.at(row[2])
      }
    end
  end

  def import_private_topics
    puts "Importing private topics..."

    topics = mysql_stream <<-SQL
      SELECT t.nodeid, t.title, t.userid, t.publishdate AS dateline
            FROM #{DB_PREFIX}node t
       LEFT JOIN #{DB_PREFIX}privatemessage pm ON pm.nodeid = t.nodeid
           WHERE pm.msgtype = 'message'
             AND t.parentid = 8
             AND t.nodeid > #{@last_imported_private_topic_id - PRIVATE_OFFSET}
        ORDER BY t.nodeid
    SQL

    create_topics(topics) do |row|
      title = row[1] || "No title given"
      {
        archetype: Archetype.private_message,
        imported_id: row[0] + PRIVATE_OFFSET,
        title: title,
        user_id: user_id_from_imported_id(row[2]),
        created_at: Time.zone.at(row[3]),
      }

    end
  end

  def import_topic_allowed_users
    puts "Importing topic allowed users..."

    allowed_users = Set.new

    mysql_stream(<<-SQL
      SELECT t.nodeid, t.userid, t.parentid
        FROM #{DB_PREFIX}node t
        LEFT JOIN #{DB_PREFIX}privatemessage pm ON pm.nodeid = t.parentid
       WHERE pm.msgtype = 'message'
       ORDER BY t.parentid
    SQL
    ).each do |row|
      next unless topic_id = topic_id_from_imported_id(row[2] + PRIVATE_OFFSET)
      next unless user_id = user_id_from_imported_id(row[1])
      allowed_users << [topic_id, user_id]
    end

    create_topic_allowed_users(allowed_users) do |row|
      {
        topic_id: row[0],
        user_id: row[1],
      }
    end
  end

  def import_private_first_posts
    puts "Importing private message first posts..."

    posts = mysql_stream <<-SQL
      SELECT p.nodeid, p.userid,
             CONVERT(CAST(rawtext AS BINARY)USING utf8),
             p.publishdate
        FROM #{DB_PREFIX}node p
        LEFT JOIN #{DB_PREFIX}text txt ON txt.nodeid = p.nodeid
        LEFT JOIN #{DB_PREFIX}privatemessage pm ON pm.nodeid = p.nodeid
       WHERE pm.msgtype = 'message'
         AND p.parentid = 8
       ORDER BY p.nodeid
    SQL

    create_posts(posts) do |row|
      {
        imported_id: row[0] + PRIVATE_OFFSET,
        topic_id: topic_id_from_imported_id(row[0] + PRIVATE_OFFSET),
        user_id: user_id_from_imported_id(row[1]),
        created_at: Time.zone.at(row[3]),
        raw: preprocess_raw(row[2]),
      }
    end
  end

  def import_private_replies
    puts "Importing private replies..."

    posts = mysql_stream <<-SQL
      SELECT p.nodeid, p.userid, p.parentid,
             CONVERT(CAST(rawtext AS BINARY)USING utf8),
             p.publishdate
        FROM #{DB_PREFIX}node p
        LEFT JOIN #{DB_PREFIX}text txt ON txt.nodeid = p.nodeid
        LEFT JOIN #{DB_PREFIX}privatemessage pm ON pm.nodeid = p.nodeid
       WHERE pm.msgtype = 'message'
         AND p.parentid != 8
       ORDER BY p.nodeid
    SQL

    create_posts(posts) do |row|
      {
        imported_id: row[0] + PRIVATE_OFFSET,
        topic_id: topic_id_from_imported_id(row[2] + PRIVATE_OFFSET),
        user_id: user_id_from_imported_id(row[1]),
        created_at: Time.zone.at(row[4]),
        raw: preprocess_raw(row[3]),
      }
    end
  end

  def create_permalink_file
    puts '', 'Creating Permalink File...', ''

    id_mapping = []

    Topic.listable_topics.find_each do |topic|
      pcf = topic.first_post.custom_fields
      if pcf && pcf["import_id"]
        id = pcf["import_id"].split('-').last
        id_mapping.push("XXX#{id}  YYY#{topic.id}")
      end
    end

    # Category.find_each do |cat|
    #   ccf = cat.custom_fields
    #   if ccf && ccf["import_id"]
    #     id = ccf["import_id"].to_i
    #     id_mapping.push("/forumdisplay.php?#{id}  http://forum.quartertothree.com#{cat.url}")
    #   end
    # end

    CSV.open(File.expand_path("../vb_map.csv", __FILE__), "w") do |csv|
      id_mapping.each do |value|
        csv << [value]
      end
    end
  end

  # find the uploaded file information from the db
  def find_upload(post, attachment_id)
    sql = "SELECT a.attachmentid attachment_id, a.userid user_id, a.filename filename,
                  a.filedata filedata, a.extension extension
             FROM #{DB_PREFIX}attachment a
            WHERE a.attachmentid = #{attachment_id}"
    results = mysql_query(sql)

    unless row = results.first
      puts "Couldn't find attachment record for attachment_id = #{attachment_id} post.id = #{post.id}"
      return
    end

    attachment_id = row[0]
    user_id = row[1]
    db_filename = row[2]

    filename = File.join(ATTACHMENT_DIR, user_id.to_s.split('').join('/'), "#{attachment_id}.attach")
    real_filename = db_filename
    real_filename.prepend SecureRandom.hex if real_filename[0] == '.'

    unless File.exists?(filename)
      puts "Attachment file #{row.inspect} doesn't exist"
      return nil
    end

    upload = create_upload(post.user.id, filename, real_filename)

    if upload.nil? || !upload.valid?
      puts "Upload not valid :("
      puts upload.errors.inspect if upload
      return
    end

    [upload, real_filename]
  rescue Mysql2::Error => e
    puts "SQL Error"
    puts e.message
    puts sql
  end
  
  def import_attachments
    puts '', 'importing attachments...'

    ext = mysql_query("SELECT GROUP_CONCAT(DISTINCT(extension)) exts FROM #{DB_PREFIX}filedata").first[0].split(',')
    SiteSetting.authorized_extensions = (SiteSetting.authorized_extensions.split("|") + ext).uniq.join("|")

    uploads = mysql_query <<-SQL
    SELECT n.parentid nodeid, a.filename, fd.userid, LENGTH(fd.filedata) AS dbsize, filedata, fd.filedataid
      FROM #{DB_PREFIX}attach a
      LEFT JOIN #{DB_PREFIX}filedata fd ON fd.filedataid = a.filedataid
      LEFT JOIN #{DB_PREFIX}node n on n.nodeid = a.nodeid
    SQL

    current_count = 0
    total_count = uploads.count

    RateLimiter.disable

    uploads.each do |upload|
      post_id = PostCustomField.where(name: 'import_id').where(value: upload[0]).first&.post_id
      if post_id.nil?
        puts "Post for #{upload['nodeid']} not found"
        next
      end
      post = Post.find(post_id)

      filename = File.join(ATTACH_DIR, upload[2].to_s.split('').join('/'), "#{upload[5]}.attach")
      real_filename = upload[1]
      real_filename.prepend SecureRandom.hex if real_filename[0] == '.'

      unless File.exists?(filename)
        # attachments can be on filesystem or in database
        # try to retrieve from database if the file did not exist on filesystem
        if upload[3].to_i == 0
          puts "Attachment file #{upload[5]} doesn't exist"
          next
        end

        tmpfile = 'attach_' + upload[5].to_s
        filename = File.join('/tmp/', tmpfile)
        File.open(filename, 'wb') { |f|
          #f.write(PG::Connection.unescape_bytea(row['filedata']))
          f.write(upload[4])
        }
      end

      upl_obj = create_upload(post.user.id, filename, real_filename)
      if upl_obj&.persisted?
        html = html_for_upload(upl_obj, real_filename)
        if !post.raw[html]
          post.raw += "\n\n#{html}\n\n"
          post.save!
          PostUpload.create!(post: post, upload: upl_obj) unless PostUpload.where(post: post, upload: upl_obj).exists?
        end
      else
        puts "Fail"
        exit
      end
      current_count += 1
      print_status(current_count, total_count)
    end
  end

  #def import_attachments
  #  puts '', 'importing attachments...'

  #  RateLimiter.disable
  #  current_count = 0

  #  total_count = mysql_query(<<-SQL
  #    SELECT COUNT(p.postid) count
  #      FROM #{DB_PREFIX}post p
  #      JOIN #{DB_PREFIX}thread t ON t.threadid = p.threadid
  #     WHERE t.firstpostid <> p.postid
  #  SQL
  #  ).first[0].to_i

  #  success_count = 0
  #  fail_count = 0

  #  attachment_regex = /\[attach[^\]]*\](\d+)\[\/attach\]/i

  #  Post.find_each do |post|
  #    current_count += 1
  #    print_status current_count, total_count

  #    new_raw = post.raw.dup
  #    new_raw.gsub!(attachment_regex) do |s|
  #      matches = attachment_regex.match(s)
  #      attachment_id = matches[1]

  #      upload, filename = find_upload(post, attachment_id)
  #      unless upload
  #        fail_count += 1
  #        next
  #        # should we strip invalid attach tags?
  #      end

  #      html_for_upload(upload, filename)
  #    end

  #    if new_raw != post.raw
  #      PostRevisor.new(post).revise!(post.user, { raw: new_raw }, bypass_bump: true, edit_reason: 'Import attachments from vBulletin')
  #    end

  #    success_count += 1
  #  end

  #  puts "", "imported #{success_count} attachments... failed: #{fail_count}."
  #  RateLimiter.enable
  #end

  def import_avatars
    if AVATAR_DIR && File.exists?(AVATAR_DIR)
      puts "", "importing user avatars"

      RateLimiter.disable
      start = Time.now
      count = 0

      Dir.foreach(AVATAR_DIR) do |item|
        print "\r%7d - %6d/sec" % [count, count.to_f / (Time.now - start)]

        next if item == ('.') || item == ('..') || item == ('.DS_Store')
        next unless item =~ /avatar(\d+)_(\d).gif/
        scan = item.scan(/avatar(\d+)_(\d).gif/)
        next unless scan[0][0].present?
        u = UserCustomField.find_by(name: "import_id", value: scan[0][0]).try(:user)
        next unless u.present?
        # raise "User not found for id #{user_id}" if user.blank?

        photo_real_filename = File.join(AVATAR_DIR, item)
        puts "#{photo_real_filename} not found" unless File.exists?(photo_real_filename)

        upload = create_upload(u.id, photo_real_filename, File.basename(photo_real_filename))
        count += 1
        if upload.persisted?
          u.import_mode = false
          u.create_user_avatar
          u.import_mode = true
          u.user_avatar.update(custom_upload_id: upload.id)
          u.update(uploaded_avatar_id: upload.id)
        else
          puts "Error: Upload did not persist for #{u.username} #{photo_real_filename}!"
        end
      end

      puts "", "imported #{count} avatars..."
      RateLimiter.enable
    end
  end

  def create_oauth_records
    puts "", "Creating OAuth records..."

    DB.exec <<~SQL
      INSERT INTO oauth2_user_infos (user_id, uid, provider, created_at, updated_at)
      SELECT u.id, ucf.value, ucf.name, ucf.created_at, ucf.created_at
        FROM user_custom_fields ucf
        JOIN users u ON u.id = ucf.user_id
       WHERE ucf.name = 'import_account_id' AND ucf.value IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL
  end

  def extract_pm_title(title)
    normalize_text(title).scrub.gsub(/^Re\s*:\s*/i, "")
  end

  def parse_birthday(birthday)
    return if birthday.blank?
    date_of_birth = Date.strptime(birthday.gsub(/[^\d-]+/, ""), "%m-%d-%Y") rescue nil
    return if date_of_birth.nil?
    date_of_birth.year < 1904 ? Date.new(1904, date_of_birth.month, date_of_birth.day) : date_of_birth
  end

  def preprocess_raw(raw)
    return "" if raw.nil?
    raw = normalize_text(raw)
    raw = raw.dup

    # [PLAINTEXT]...[/PLAINTEXT]
    raw.gsub!(/\[\/?PLAINTEXT\]/i, "\n\n```\n\n")

    # [FONT=font]...[/FONT]
    raw.gsub!(/\[FONT=\w*\]/im, "")
    raw.gsub!(/\[\/FONT\]/im, "")

    # @[URL=<user_profile>]<username>[/URL]
    # [USER=id]username[/USER]
    # [MENTION=id]username[/MENTION]
    raw.gsub!(/@\[URL=\"\S+\"\]([\w\s]+)\[\/URL\]/i) { "@#{$1.gsub(" ", "_")}" }
    raw.gsub!(/\[USER=\"\d+\"\]([\S]+)\[\/USER\]/i) { "@#{$1.gsub(" ", "_")}" }
    raw.gsub!(/\[MENTION=\d+\]([\S]+)\[\/MENTION\]/i) { "@#{$1.gsub(" ", "_")}" }

    # [TABLE]...[/TABLE]
    raw.gsub!(/\[TABLE=\\"[\w:\-\s,]+\\"\]/i, "")
    raw.gsub!(/\[\/TABLE\]/i, "")

    # [HR]...[/HR]
    raw.gsub(/\[HR\]\s*\[\/HR\]/im, "---")

    # [VIDEO=youtube_share;<id>]...[/VIDEO]
    # [VIDEO=vimeo;<id>]...[/VIDEO]
    raw.gsub!(/\[VIDEO=YOUTUBE_SHARE;([^\]]+)\].*?\[\/VIDEO\]/i) { "\nhttps://www.youtube.com/watch?v=#{$1}\n" }
    raw.gsub!(/\[VIDEO=VIMEO;([^\]]+)\].*?\[\/VIDEO\]/i) { "\nhttps://vimeo.com/#{$1}\n" }

    # remove attachments
    raw.gsub!(/\[attach[^\]]*\].*\[\/attach\]/i, "")

    raw
  end

  def print_status(current, max, start_time = nil)
    if start_time.present?
      elapsed_seconds = Time.now - start_time
      elements_per_minute = '[%.0f items/min]  ' % [current / elapsed_seconds.to_f * 60]
    else
      elements_per_minute = ''
    end

    print "\r%9d / %d (%5.1f%%)  %s" % [current, max, current / max.to_f * 100, elements_per_minute]
  end

  def mysql_stream(sql)
    @client.query(sql, stream: true)
  end

  def mysql_query(sql)
    @client.query(sql)
  end

end

BulkImport::VBulletin5.new.run

